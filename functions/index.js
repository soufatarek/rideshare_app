const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

// ============================================================
// POLAR.SH CONFIGURATION (server-side only — never exposed)
// ============================================================
const POLAR_CONFIG = {
  accessToken: "polar_oat_q1QRq74WLAYjyrRRoPtY5PXc6zm1UCxK21k5E1P9yPw",
  productId: "bbb4cd82-710a-4d3b-bc00-d4ff9cf3b1de",
  // Toggle between sandbox and production:
  baseUrl: "https://sandbox-api.polar.sh/v1",
  // baseUrl: "https://api.polar.sh/v1",  // Uncomment for production
};

// ============================================================
// CALLABLE: createPolarCheckout
// Creates a Polar.sh checkout session for ride payment.
// ============================================================
exports.createPolarCheckout = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const { amount, rideId, currency } = request.data;

  if (!amount || !rideId) {
    throw new HttpsError(
      "invalid-argument",
      "amount and rideId are required."
    );
  }

  try {
    const response = await fetch(`${POLAR_CONFIG.baseUrl}/checkouts/`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${POLAR_CONFIG.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        product_id: POLAR_CONFIG.productId,
        amount: Math.round(amount * 100), // Convert to cents
        currency: currency || "usd",
        metadata: {
          ride_id: rideId,
          rider_id: request.auth.uid,
        },
        success_url: `rideshare://payment/success?ride_id=${rideId}`,
        cancel_url: `rideshare://payment/cancel?ride_id=${rideId}`,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error("Polar checkout error:", data);
      throw new HttpsError("internal", "Failed to create checkout session.");
    }

    // Store payment intent in Firestore for tracking
    await admin.firestore().collection("payments").doc(rideId).set({
      rideId: rideId,
      riderId: request.auth.uid,
      amount: amount,
      currency: currency || "usd",
      checkoutId: data.id || null,
      checkoutUrl: data.url || null,
      status: "pending",
      provider: "polar",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Polar checkout created for ride ${rideId}: ${data.url}`);

    return { checkoutUrl: data.url, checkoutId: data.id };
  } catch (error) {
    console.error("Polar checkout exception:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Payment service unavailable.");
  }
});

// ============================================================
// CALLABLE: verifyPolarPayment
// Checks if a Polar payment was completed for a ride.
// ============================================================
exports.verifyPolarPayment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const { rideId } = request.data;
  if (!rideId) {
    throw new HttpsError("invalid-argument", "rideId is required.");
  }

  try {
    const response = await fetch(
      `${POLAR_CONFIG.baseUrl}/orders/?metadata[ride_id]=${rideId}`,
      {
        headers: {
          Authorization: `Bearer ${POLAR_CONFIG.accessToken}`,
          "Content-Type": "application/json",
        },
      }
    );

    const data = await response.json();
    const paid = data.items && data.items.length > 0;

    // Update payment record in Firestore
    if (paid) {
      await admin.firestore().collection("payments").doc(rideId).update({
        status: "completed",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { paid, orderId: paid ? data.items[0].id : null };
  } catch (error) {
    console.error("Polar verify exception:", error);
    throw new HttpsError("internal", "Payment verification failed.");
  }
});

// ============================================================
// CALLABLE: requestPolarRefund
// Refunds a completed Polar payment.
// ============================================================
exports.requestPolarRefund = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const { orderId, reason } = request.data;
  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }

  try {
    const response = await fetch(`${POLAR_CONFIG.baseUrl}/refunds/`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${POLAR_CONFIG.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        order_id: orderId,
        reason: reason || "Ride cancelled",
      }),
    });

    if (response.ok) {
      console.log(`Refund issued for order ${orderId}`);
      return { success: true };
    } else {
      const data = await response.json();
      console.error("Polar refund error:", data);
      throw new HttpsError("internal", "Refund failed.");
    }
  } catch (error) {
    console.error("Polar refund exception:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Refund service unavailable.");
  }
});

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
