import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/app_notification.dart';
import '../application/notifications_controller.dart';

/// Marchează notificarea ca citită și navighează la destinația potrivită
/// tipului ei. Partajat între ecranul de notificări și halo-ul din header
/// (Batch 7), ca logica de rutare să existe într-un singur loc.
void openNotification(
  BuildContext context,
  WidgetRef ref,
  AppNotification notification,
) {
  ref.read(notificationsControllerProvider.notifier).markAsRead(notification.id);
  switch (notification.type) {
    case NotificationType.wishlistBookAvailable:
      context.push('/wishlist');
    case NotificationType.newMessage:
      final conversationId = notification.data?['conversationId'] as String?;
      if (conversationId != null) {
        context.push('/chat/$conversationId');
      }
    case NotificationType.exchangeRequestReceived:
    case NotificationType.exchangeRequestRejected:
    case NotificationType.exchangeMeetingScheduled:
    case NotificationType.exchangeBookPending:
    case NotificationType.exchangeReopened:
      context.push('/exchanges');
    case NotificationType.exchangeRequestAccepted:
    case NotificationType.exchangeMeetingProposed:
    case NotificationType.exchangeMeetingAccepted:
    case NotificationType.exchangeMeetingDeclined:
    case NotificationType.exchangeContactShared:
    case NotificationType.exchangeReady:
    case NotificationType.exchangePostponed:
    case NotificationType.exchangeDonePendingConfirmation:
    case NotificationType.exchangeDoneDisputed:
    case NotificationType.exchangeCompleted:
    case NotificationType.exchangeCancelled:
      // Aceste tipuri sunt partajate între schimburile carte-contra-carte
      // (exchangeRequestId în data) și vânzările cu bani (offerId în data) -
      // vezi backend/src/offers/offers.service.ts, care refolosește aceleași
      // NotificationType-uri EXCHANGE_* ca exchanges.service.ts.
      final exchangeRequestId = notification.data?['exchangeRequestId'] as String?;
      final offerId = notification.data?['offerId'] as String?;
      if (exchangeRequestId != null) {
        context.push('/exchanges/$exchangeRequestId/ready');
      } else if (offerId != null) {
        context.push('/offers/$offerId/ready');
      } else {
        context.push('/exchanges');
      }
    case NotificationType.priceOfferAccepted:
      // Odată acceptată, oferta intră în flow-ul de "ready to sell" (programare
      // etc.) - nu mai e doar un card de chat, ca înainte de sale-flow v2.
      final acceptedOfferId = notification.data?['offerId'] as String?;
      if (acceptedOfferId != null) {
        context.push('/offers/$acceptedOfferId/ready');
      } else {
        context.push('/exchanges');
      }
    case NotificationType.priceOfferReceived:
    case NotificationType.priceOfferRejected:
      // Oferta e vizibilă și acționabilă direct în chat (vezi
      // Message.priceOfferId) - trimitem acolo, nu la ecranul separat de
      // schimburi. Notificările vechi n-au conversationId - fallback /exchanges.
      final conversationId = notification.data?['conversationId'] as String?;
      if (conversationId != null) {
        context.push('/chat/$conversationId');
      } else {
        context.push('/exchanges');
      }
    case NotificationType.followedUserNewBook:
      // Duce direct la anunțul nou postat, nu la profilul proprietarului -
      // userBookId lipsește doar la notificările vechi, dinainte de a fi
      // trimis de backend (vezi follow.service.ts), caz în care rămânem cu
      // fallback pe profil.
      final newBookUserBookId = notification.data?['userBookId'] as String?;
      final followedUserId = notification.data?['userId'] as String?;
      if (newBookUserBookId != null) {
        context.push('/books/$newBookUserBookId');
      } else if (followedUserId != null) {
        context.push('/users/$followedUserId');
      }
    case NotificationType.nearbyBookListed:
    case NotificationType.interestBookListed:
      context.push('/search');
    case NotificationType.unknown:
      break; // tip necunoscut clientului - afișăm textul, fără acțiune la tap
    case NotificationType.priceChanged:
      context.push('/wishlist');
    case NotificationType.outbid:
    case NotificationType.auctionWon:
    case NotificationType.auctionEnded:
      final auctionId = notification.data?['auctionId'] as String?;
      if (auctionId != null) {
        context.push('/auctions/$auctionId');
      }
  }
}
