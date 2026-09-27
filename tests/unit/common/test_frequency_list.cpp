#include <QtTest>

#include <algorithm>

#include <QJsonArray>
#include <QTemporaryFile>
#include <QTranslator>

#include "models/Bands.hpp"
#include "models/FrequencyList.hpp"

namespace
{
  using WorkingFrequencies = FrequencyList_v2_101;

  class LocaleGuard
  {
  public:
    ~LocaleGuard () { QLocale::setDefault (original_); }
  private:
    QLocale original_;
  };

  class RegionTranslator : public QTranslator
  {
  public:
    bool isEmpty () const override { return false; }
    QString translate (char const * context, char const * source,
                       char const * = nullptr, int = -1) const override
    {
      if (QString::fromLatin1 (context) == "IARURegions")
        return "Translated " + QString::fromLatin1 (source);
      return {};
    }
  };

  QList<Radio::Frequency> visible_frequencies (WorkingFrequencies const& model)
  {
    QList<Radio::Frequency> result;
    for (auto const& item : model) result.append (item.frequency_);
    std::sort (result.begin (), result.end ());
    return result;
  }

  Radio::Frequency selected_frequency (WorkingFrequencies const& model, int row)
  {
    if (row < 0 || row >= model.rowCount ()) return 0;
    return model.frequency_list ({model.index (row, 0)}).value (0).frequency_;
  }
}

class TestFrequencyList : public QObject
{
  Q_OBJECT

private Q_SLOTS:
  void json_round_trip_data ();
  void json_round_trip ();
  void invalid_documents_data ();
  void invalid_documents ();
  void invalid_entries_are_isolated ();
  void eligibility_filters ();
  void selection_uses_eligible_frequencies ();
};

void TestFrequencyList::json_round_trip_data ()
{
  QTest::addColumn<QString> ("locale_name");
  QTest::addColumn<bool> ("translated");
  QTest::newRow ("C") << QStringLiteral ("C") << false;
  QTest::newRow ("decimal-comma") << QStringLiteral ("de_DE") << false;
  QTest::newRow ("translated-regions") << QStringLiteral ("C") << true;
}

void TestFrequencyList::json_round_trip ()
{
  QFETCH (QString, locale_name);
  QFETCH (bool, translated);
  LocaleGuard restore_locale;
  QLocale::setDefault (QLocale {locale_name});
  RegionTranslator translator;
  if (translated) QVERIFY (QCoreApplication::installTranslator (&translator));

  Bands bands;
  WorkingFrequencies model {&bands};
  WorkingFrequencies::FrequencyItems const expected {
    {1000001, Modes::FreqCal, IARURegions::R1, "Reference", "Test source",
     QDateTime::fromString ("2026-01-01T12:34:56Z", Qt::ISODate),
     QDateTime::fromString ("2026-12-31T12:34:56Z", Qt::ISODate), true},
    {14074000, Modes::FT8, IARURegions::ALL, {}, {}, {}, {}, false},
    {7078000, Modes::ALL, IARURegions::R2, {}, {}, {}, {}, false}
  };
  QTemporaryFile file;
  QVERIFY (file.open ());
  model.to_json_file (&file, "test", "101", expected);
  QVERIFY (file.seek (0));
  auto const actual = WorkingFrequencies::from_json_file (&file);
  QCOMPARE (actual.size (), expected.size ());
  for (int i = 0; i < expected.size (); ++i) QCOMPARE (actual[i], expected[i]);
}

void TestFrequencyList::invalid_documents_data ()
{
  QTest::addColumn<QByteArray> ("contents");
  QTest::newRow ("malformed") << QByteArray {"{"};
  QTest::newRow ("missing-frequencies") << QByteArray {"{\"wsjtx_file\":\"qrg\"}"};
  QTest::newRow ("empty-frequencies") << QByteArray {"{\"frequencies\":[]}"};
}

void TestFrequencyList::invalid_documents ()
{
  QFETCH (QByteArray, contents);
  QTemporaryFile file;
  QVERIFY (file.open ());
  QCOMPARE (file.write (contents), qint64 (contents.size ()));
  QVERIFY (file.seek (0));
  QVERIFY_EXCEPTION_THROWN (WorkingFrequencies::from_json_file (&file), ReadFileException);
}

void TestFrequencyList::invalid_entries_are_isolated ()
{
  QJsonObject const valid {{"frequency", "14.074000"}, {"mode", "FT8"},
                           {"region", "Region 1"}};
  QJsonArray entries;
  for (auto const& frequency : {"invalid", "-1", "18446744073709.551616", "0"})
    {
      auto invalid = valid;
      invalid["frequency"] = frequency;
      entries.append (invalid);
    }
  for (auto const& field : {"mode", "region"})
    {
      auto invalid = valid;
      invalid[field] = "Unknown";
      entries.append (invalid);
    }
  entries.insert (2, valid);
  QTemporaryFile file;
  QVERIFY (file.open ());
  auto const contents = QJsonDocument {QJsonObject {{"frequencies", entries}}}.toJson ();
  QCOMPARE (file.write (contents), qint64 (contents.size ()));
  QVERIFY (file.seek (0));
  auto const actual = WorkingFrequencies::from_json_file (&file);
  QCOMPARE (actual.size (), 1);
  QCOMPARE (actual.front ().frequency_, Radio::Frequency {14074000});
  QCOMPARE (actual.front ().mode_, Modes::FT8);
  QCOMPARE (actual.front ().region_, IARURegions::R1);
}

void TestFrequencyList::eligibility_filters ()
{
  Bands bands;
  WorkingFrequencies model {&bands};
  auto const now = QDateTime::currentDateTimeUtc ();
  model.frequency_list ({
    {14074000, Modes::FT8, IARURegions::R1, {}, {}, now.addDays (-1), now.addDays (1), false},
    {7074000, Modes::FT8, IARURegions::ALL, {}, {}, {}, {}, false},
    {10136000, Modes::ALL, IARURegions::R1, {}, {}, {}, {}, false},
    {50313000, Modes::FT8, IARURegions::R2, {}, {}, {}, {}, false},
    {14080000, Modes::FT4, IARURegions::R1, {}, {}, {}, {}, false},
    {10000000, Modes::FreqCal, IARURegions::ALL, {}, {}, {}, {}, false},
    {3573000, Modes::FT8, IARURegions::R1, {}, {}, {}, now.addDays (-1), false},
    {1840000, Modes::FT8, IARURegions::R1, {}, {}, now.addDays (1), {}, false}
  });
  model.filter (IARURegions::R1, Modes::FT8, true);
  QCOMPARE (visible_frequencies (model), (QList<Radio::Frequency> {7074000, 10136000, 14074000}));
  model.filter (IARURegions::R1, Modes::FT8, false);
  QCOMPARE (visible_frequencies (model), (QList<Radio::Frequency> {1840000, 3573000, 7074000, 10136000, 14074000}));
  model.filter (IARURegions::R1, Modes::FreqCal, true);
  QCOMPARE (visible_frequencies (model), (QList<Radio::Frequency> {10000000}));
  model.filter (IARURegions::ALL, Modes::ALL, false);
  QCOMPARE (model.rowCount (), 8);
}

void TestFrequencyList::selection_uses_eligible_frequencies ()
{
  Bands bands;
  WorkingFrequencies model {&bands};
  WorkingFrequencies::Item const preferred {14074000, Modes::FT8, IARURegions::ALL,
                                      {}, {}, {}, {}, true};
  model.frequency_list ({
    preferred,
    {14080000, Modes::FT8, IARURegions::R1, {}, {}, {}, {}, false},
    {14090000, Modes::FT8, IARURegions::R1, {}, {}, {}, {}, false},
    {14081000, Modes::FT8, IARURegions::R2, {}, {}, {}, {}, true},
    {7074000, Modes::FT8, IARURegions::R2, {}, {}, {}, {}, true}
  });
  model.filter (IARURegions::R1, Modes::FT8, false);
  QCOMPARE (selected_frequency (model, model.best_working_frequency (Radio::Frequency {14081000})),
            preferred.frequency_);
  QCOMPARE (selected_frequency (model, model.best_working_frequency (QString {"20m"})),
            preferred.frequency_);
  QVERIFY (model.remove (preferred));
  QCOMPARE (selected_frequency (model, model.best_working_frequency (Radio::Frequency {14081000})),
            Radio::Frequency {14080000});
  QCOMPARE (model.best_working_frequency (Radio::Frequency {7074000}), -1);
  QCOMPARE (model.best_working_frequency (QString {"40m"}), -1);
}

QTEST_GUILESS_MAIN (TestFrequencyList)
#include "test_frequency_list.moc"
