const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

// ============================================================
// PRICING CONFIGURATION (EGP — Egyptian Pounds)
// ============================================================
const VEHICLE_PRICING = {
  Economy: { baseFare: 15.0, perKmRate: 5.0, perMinuteRate: 0.5 },
  Comfort: { baseFare: 30.0, perKmRate: 12.0, perMinuteRate: 1.0 },
  XL: { baseFare: 20.0, perKmRate: 7.0, perMinuteRate: 0.7 },
  // Fallback by old vehicle IDs
  "1": { baseFare: 15.0, perKmRate: 5.0, perMinuteRate: 0.5 },
  "2": { baseFare: 30.0, perKmRate: 12.0, perMinuteRate: 1.0 },
  "3": { baseFare: 20.0, perKmRate: 7.0, perMinuteRate: 0.7 },
};

/**
 * Calculate surge multiplier based on Egypt time (UTC+2).
 * Rush hours: 7–9 AM, 5–8 PM → 1.5×
 * Late night: 11 PM–5 AM → 1.25×
 * Normal: 1.0×
 */
function getSurgeMultiplier() {
  const now = new Date();
  // Convert to Egypt time (UTC+2)
  const egyptHour = (now.getUTCHours() + 2) % 24;

  if ((egyptHour >= 7 && egyptHour < 9) || (egyptHour >= 17 && egyptHour < 20)) {
    return 1.5; // Rush hour
  }
  if (egyptHour >= 23 || egyptHour < 5) {
    return 1.25; // Late night
  }
  return 1.0; // Normal
}

/**
 * Calculate server-side price.
 */
function calculateServerPrice(vehicleType, distanceKm) {
  const pricing = VEHICLE_PRICING[vehicleType];
  if (!pricing) {
    // Fallback to Economy if unknown vehicle type
    return calculateServerPrice("Economy", distanceKm);
  }

  const tripMinutes = Math.ceil(distanceKm * 2); // ~30 km/h in city
  const baseFare =
    pricing.baseFare +
    pricing.perKmRate * distanceKm +
    pricing.perMinuteRate * tripMinutes;

  const surgeMultiplier = getSurgeMultiplier();
  const finalPrice = Math.round(baseFare * surgeMultiplier);

  return { finalPrice, surgeMultiplier, baseFare: Math.round(baseFare) };
}

// ============================================================
// CALLABLE: getEstimatedPrice
// Called by the rider app before confirming a ride.
// ============================================================
exports.getEstimatedPrice = onCall(async (request) => {
  // Require authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const { vehicleType, distanceKm } = request.data;

  if (!vehicleType || distanceKm === undefined || distanceKm < 0) {
    throw new HttpsError(
      "invalid-argument",
      "vehicleType and distanceKm are required."
    );
  }

  const result = calculateServerPrice(vehicleType, distanceKm);

  return {
    estimatedPrice: result.finalPrice,
    baseFare: result.baseFare,
    surgeMultiplier: result.surgeMultiplier,
    currency: "EGP",
  };
});

// ============================================================
// TRIGGER: onRideRequestCreated
// Fires when a new ride_requests/{requestId} is created.
// Sets server-side price and notifies drivers.
// ============================================================
exports.onRideRequestCreated = onDocumentCreated(
  "ride_requests/{requestId}",
  async (event) => {
    const data = event.data.data();
    const requestId = event.params.requestId;

    if (!data) return null;

    // Calculate and set server-side price
    const vehicleType = data.vehicleType || "Economy";
    const distanceKm = data.distanceKm || 0;
    const { finalPrice, surgeMultiplier, baseFare } = calculateServerPrice(
      vehicleType,
      distanceKm
    );

    // Write server price to the document
    await event.data.ref.update({
      price: finalPrice,
      serverPrice: finalPrice,
      baseFare: baseFare,
      surgeMultiplier: surgeMultiplier,
    });

    console.log(
      `Ride ${requestId}: server price set to ${finalPrice} EGP (surge: ${surgeMultiplier}x)`
    );

    // Notify all drivers via topic
    try {
      const notification = {
        title: "🚗 New Ride Request!",
        body: `Pickup: ${data.pickupAddress || "Unknown"} → ${data.dropoffAddress || "Unknown"}`,
      };
      const msgData = {
        type: "searching",
        ride_request: JSON.stringify({ id: requestId, ...data, price: finalPrice }),
      };

      await admin.messaging().send({
        topic: "drivers",
        notification: notification,
        data: msgData,
      });
      console.log(`Notification sent to drivers topic for ride ${requestId}`);
    } catch (error) {
      console.error("Error sending driver notification:", error);
    }

    return null;
  }
);

// ============================================================
// TRIGGER: onRideRequestStatusChanged
// Fires on any update to ride_requests/{requestId}.
// ============================================================
exports.onRideRequestStatusChanged = onDocumentUpdated(
  "ride_requests/{requestId}",
  async (event) => {
    const newValue = event.data.after.data();
    const previousValue = event.data.before.data();
    const requestId = event.params.requestId;

    // If there's no status change, don't do anything
    if (newValue.status === previousValue.status) {
      return null;
    }

    const status = newValue.status;

    // ----------------------------------------------------------
    // SERVER-SIDE PRICE on new ride request
    // ----------------------------------------------------------
    if (status === "searching" && previousValue.status !== "searching") {
      const vehicleType = newValue.vehicleType || "Economy";
      const distanceKm = newValue.distanceKm || 0;
      const { finalPrice, surgeMultiplier, baseFare } = calculateServerPrice(
        vehicleType,
        distanceKm
      );

      // Overwrite price with server-calculated value
      await event.data.after.ref.update({
        price: finalPrice,
        serverPrice: finalPrice,
        baseFare: baseFare,
        surgeMultiplier: surgeMultiplier,
      });

      // Update newValue for notification payload
      newValue.price = finalPrice;
      newValue.serverPrice = finalPrice;
      newValue.surgeMultiplier = surgeMultiplier;
    }

    // ----------------------------------------------------------
    // NOTIFICATIONS (status changes only — not initial create)
    // ----------------------------------------------------------
    const notification = { title: "", body: "" };
    const data = {
      type: status,
      ride_request: JSON.stringify({ id: requestId, ...newValue }),
    };

    let targetToken = null;
    let targetTopic = null;

    switch (status) {
      case "searching":
        notification.title = "🚗 New Ride Request!";
        notification.body = `Pickup: ${newValue.pickupAddress} → ${newValue.dropoffAddress}`;
        targetTopic = "drivers";
        break;

      case "accepted":
        notification.title = "Driver Assigned";
        notification.body = `${newValue.driverName} is your driver. They will arrive soon.`;
        targetToken = await getUserToken(newValue.riderId);
        break;

      case "arriving":
        notification.title = "Driver Arriving";
        notification.body = `${newValue.driverName} has arrived at your pickup location.`;
        targetToken = await getUserToken(newValue.riderId);
        break;

      case "in_progress":
        notification.title = "Trip Started";
        notification.body = "Your trip has started. Enjoy your ride!";
        targetToken = await getUserToken(newValue.riderId);
        break;

      case "completed":
        notification.title = "Trip Completed";
        notification.body = "You have arrived at your destination.";
        targetToken = await getUserToken(newValue.riderId);
        // Archive to trips collection & update driver earnings
        await archiveTrip(requestId, newValue);
        break;

      case "cancelled":
        notification.title = "Ride Cancelled";
        notification.body = "The ride has been cancelled.";
        // Notify driver if assigned
        if (newValue.driverId) {
          const driverToken = await getDriverToken(newValue.driverId);
          if (driverToken) {
            await admin
              .messaging()
              .send({
                token: driverToken,
                notification: notification,
                data: data,
              })
              .catch(console.error);
          }
        }
        targetToken = await getUserToken(newValue.riderId);
        break;

      default:
        return null;
    }

    // Send notification
    try {
      if (targetToken) {
        console.log(`Sending notification to token: ${targetToken}`);
        await admin.messaging().send({
          token: targetToken,
          notification: notification,
          data: data,
        });
      } else if (targetTopic) {
        console.log(`Sending notification to topic: ${targetTopic}`);
        await admin.messaging().send({
          topic: targetTopic,
          notification: notification,
          data: data,
        });
      }
    } catch (error) {
      console.error("Error sending message:", error);
    }

    return null;
  }
);

// ============================================================
// HELPER: Archive completed trip + update driver earnings
// ============================================================
async function archiveTrip(requestId, rideData) {
  const db = admin.firestore();

  try {
    // Create trip document
    await db
      .collection("trips")
      .doc(requestId)
      .set({
        id: requestId,
        userId: rideData.riderId || "",
        driverId: rideData.driverId || "",
        date: admin.firestore.FieldValue.serverTimestamp(),
        cost: rideData.serverPrice || rideData.price || 0,
        status: "completed",
        pickupAddress: rideData.pickupAddress || "",
        dropoffAddress: rideData.dropoffAddress || "",
        pickupLocation: rideData.pickupLocation || null,
        dropoffLocation: rideData.dropoffLocation || null,
        vehicleType: rideData.vehicleType || "",
        surgeMultiplier: rideData.surgeMultiplier || 1.0,
        paymentMethod: rideData.paymentMethod || "Cash",
        distanceKm: rideData.distanceKm || 0,
        riderName: rideData.riderName || "",
        driverName: rideData.driverName || "",
        rating: null,
      });

    console.log(`Trip ${requestId} archived successfully.`);

    // Update driver earnings
    if (rideData.driverId) {
      const earnings = rideData.serverPrice || rideData.price || 0;
      await db
        .collection("drivers")
        .doc(rideData.driverId)
        .update({
          totalEarnings: admin.firestore.FieldValue.increment(earnings),
          totalTrips: admin.firestore.FieldValue.increment(1),
        });
      console.log(
        `Driver ${rideData.driverId} earnings updated: +${earnings} EGP`
      );
    }
  } catch (error) {
    console.error("Error archiving trip:", error);
  }
}

// ============================================================
// HELPERS: Get FCM tokens
// ============================================================
async function getUserToken(userId) {
  if (!userId) return null;
  const doc = await admin.firestore().collection("users").doc(userId).get();
  if (doc.exists) {
    return doc.data().fcmToken || null;
  }
  return null;
}

async function getDriverToken(driverId) {
  if (!driverId) return null;
  const doc = await admin
    .firestore()
    .collection("drivers")
    .doc(driverId)
    .get();
  if (doc.exists) {
    return doc.data().fcmToken || null;
  }
  return null;
}
