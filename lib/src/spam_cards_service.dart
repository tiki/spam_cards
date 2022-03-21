import 'package:decision_sdk/decision.dart';
import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';
import 'package:spam_cards/src/spam_cards_presenter.dart';
import 'package:spam_cards/src/spam_cards_style.dart';

import 'model/spam_cards_model.dart';
import 'ui/spam_cards_layout.dart';

class SpamCardsService extends ChangeNotifier {
  final _log = Logger('SpamCardsService');
  final DecisionSdk decisionSdk;
  final SpamCardsStyle style;
  late final SpamCardsPresenter presenter;

  SpamCardsService({required this.decisionSdk, required this.style}) {
    presenter = SpamCardsPresenter(this);
  }

  Future<void> addCards(
      {Function(int senderId)? onUnsubscribe,
      Function(int senderId)? onKeep,
      required String provider,
      required List messages}) async {
    List<SpamCardsModel> spamModels = [];
    String calculatedFrequency = _calculateFrequency(messages);
    double calculatedOpenRate = _calculateOpenRate(messages);
    spamModels.add(SpamCardsModel.fromMessageList(
        messages: messages,
        calculatedFrequency: calculatedFrequency,
        calculatedOpenRate: calculatedOpenRate,
        provider: provider,
        onKeep: onKeep,
        onUnsubscribe: onUnsubscribe));
    decisionSdk.addCards(spamModels
        .map((spamModel) => SpamCardsLayout(this, spamModel))
        .toList());
  }

  String _calculateFrequency(List<dynamic> messages) {
    const int secsInDay = 86400;
    const int secsInWeek = 604800;
    const int secsInMonth = 2629746;

    if (messages.length == 1) return "once";

    messages.sort((a, b) => a.receivedDate!.isBefore(b.receivedDate!) ? -1 : 1);
    List<Duration> freq = [];
    for (int i = 0; i < messages.length - 1; i++) {
      freq.add(
          messages[i].receivedDate!.difference(messages[i + 1].receivedDate!));
    }
    double avgSeconds = 0;
    freq.map((f) => f.inSeconds).forEach((f) => avgSeconds += f);
    avgSeconds = (avgSeconds / freq.length).abs();

    if (avgSeconds <= secsInDay) {
      return "daily";
    } else if (avgSeconds <= secsInWeek) {
      return "weekly";
    } else if (avgSeconds <= secsInMonth) {
      return "monthly";
    } else if (avgSeconds <= secsInMonth * 3) {
      return "quarterly";
    } else if (avgSeconds <= secsInMonth * 6) {
      return "semiannually";
    } else {
      return "annually";
    }
  }

  double _calculateOpenRate(List<dynamic> messages) {
    int opened = 0;
    int total = messages.length;
    for (var message in messages) {
      if (message.openedDate != null) opened++;
    }
    return opened / total;
  }
}