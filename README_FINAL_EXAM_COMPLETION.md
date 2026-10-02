# GoldenFinds — Final Examination Completion Patch

This patch completes the mandatory checkout workflow from the Flutter final examination.

## Fixed exchange rates

GoldenFinds intentionally uses fixed examination rates (no live currency API):

- 1 USD = 3,000 BIF
- 1 EUR = 3,300 BIF

Delivery fee:
- 5,000 BIF equivalent per seller order when `Delivery` is selected.
- 0 when `Physical boutique pickup` is selected.

A cart that contains products from different sellers creates one Firestore order per seller,
so each seller can only access and fulfil their own order.

## Simulated payment

Two simulated methods are provided:
- Mobile Money
- Bank Card

`Simulate failed payment` demonstrates a failed payment without creating an order.
`Pay & confirm order` simulates a successful payment, stores `paymentStatus = paid`,
and creates the Firestore order.

No real money is transferred.

## Firestore order data

New orders store:
- client and seller information
- items
- subtotal
- delivery fee
- total
- selected currency
- delivery/pickup option
- delivery location and phone when applicable
- payment method
- payment status
- order status
- timestamps

## WhatsApp

After a successful order, the confirmation dialog offers `Send Order via WhatsApp`.
The same action is available from client order history.
If WhatsApp cannot be opened, GoldenFinds shows a message and does not crash.

## Product images

The existing compressed Firestore image remains as a durable fallback.
CatalogService now also attempts to upload the compressed JPEG to Firebase Storage under:

`products/{sellerId}/{productId}.jpg`

and stores the resulting download URL in `imageUrl` when Storage is available.

## Required validation

Run:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
firebase deploy --only firestore,storage
flutter run -d chrome
```

Do not build the final APK until the complete browser workflow has been validated.
