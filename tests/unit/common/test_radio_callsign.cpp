#include <QtTest>

#include "Radio.hpp"

class TestRadioCallsign final : public QObject
{
  Q_OBJECT

private Q_SLOTS:
  void identity_data ();
  void identity ();
  void classification_data ();
  void classification ();
};

void TestRadioCallsign::identity_data ()
{
  QTest::addColumn<QString> ("callsign");
  QTest::addColumn<QString> ("base");
  QTest::addColumn<QString> ("prefix");

  QTest::newRow ("ordinary") << QString {"K1ABC"} << QString {"K1ABC"} << QString {"K1ABC"};
  QTest::newRow ("portable prefix") << QString {"EA8/K1ABC"} << QString {"K1ABC"} << QString {"EA8"};
  QTest::newRow ("portable suffix") << QString {"K1ABC/EA8"} << QString {"K1ABC"} << QString {"EA8"};
  QTest::newRow ("equal length") << QString {"EA8/K1A"} << QString {"K1A"} << QString {"EA8"};
}

void TestRadioCallsign::identity ()
{
  QFETCH (QString, callsign);
  QFETCH (QString, base);
  QFETCH (QString, prefix);

  for (auto const& suffix : {QString {}, QString {"/P"}, QString {"/QRP"}, QString {"/P/QRP"}})
    {
      auto const input = callsign + suffix;
      QCOMPARE (Radio::base_callsign (input), base);
      QCOMPARE (Radio::effective_prefix (input), prefix);
      QCOMPARE (Radio::base_callsign (input.toLower ()), base);
      QCOMPARE (Radio::effective_prefix (input.toLower ()), prefix);
    }
}

void TestRadioCallsign::classification_data ()
{
  QTest::addColumn<QString> ("callsign");
  QTest::addColumn<bool> ("valid");
  QTest::addColumn<bool> ("compound");
  QTest::addColumn<bool> ("nonstandard");

  QTest::newRow ("standard") << QString {"K1ABC"} << true << false << false;
  QTest::newRow ("compound") << QString {"K1ABC/P"} << true << true << true;
  QTest::newRow ("long prefix") << QString {"3DA0XYZ"} << true << false << true;
  QTest::newRow ("invalid alphabet") << QString {"---"} << false << false << false;
  QTest::newRow ("empty") << QString {} << false << false << false;
}

void TestRadioCallsign::classification ()
{
  QFETCH (QString, callsign);
  QFETCH (bool, valid);
  QFETCH (bool, compound);
  QFETCH (bool, nonstandard);

  QCOMPARE (Radio::is_callsign (callsign), valid);
  QCOMPARE (Radio::is_compound_callsign (callsign), compound);
  QCOMPARE (Radio::is_77bit_nonstandard_callsign (callsign), nonstandard);
}

QTEST_GUILESS_MAIN (TestRadioCallsign)

#include "test_radio_callsign.moc"
