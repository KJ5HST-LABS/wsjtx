#include "wsjtx_config.h"

#include <QtTest>
#include <QList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QStringList>
#include <QTemporaryDir>
#include <QUrl>

#include "SampleDownloader.hpp"
#include "SampleDownloader/RemoteFile.hpp"

namespace
{
  class UnsentReply final
    : public QNetworkReply
  {
  public:
    UnsentReply (QNetworkAccessManager::Operation operation, QNetworkRequest const& request, QObject * parent)
      : QNetworkReply {parent}
    {
      setOperation (operation);
      setRequest (request);
      setUrl (request.url ());
      setError (QNetworkReply::OperationCanceledError, "not sent");
      setFinished (true);
    }

    void abort () override {}

  private:
    qint64 readData (char *, qint64) override { return -1; }
  };

  class NoTlsNetworkAccessManager final
    : public QNetworkAccessManager
  {
    Q_OBJECT

  public:
    QList<QUrl> requested;

  protected:
    QNetworkReply * createRequest (Operation operation, QNetworkRequest const& request, QIODevice *) override
    {
      requested << request.url ();
      return new UnsentReply {operation, request, this};
    }

  protected Q_SLOTS:
    QStringList supportedSchemesImplementation () const
    {
      auto schemes = QNetworkAccessManager::supportedSchemesImplementation ();
      schemes.removeAll ("https");
      return schemes;
    }
  };

  class Listener final
    : public RemoteFile::ListenerInterface
  {
  public:
    void error (QString const& title, QString const& message) override
    {
      errors << title + ": " + message;
    }

    void download_finished (bool success) override
    {
      finished << success;
    }

    QStringList errors;
    QList<bool> finished;
  };
}

class TestSampleDownloader final
  : public QObject
{
  Q_OBJECT

private Q_SLOTS:
  void unsaved_url_reads_as_pages ()
  {
    QTemporaryDir directory;
    QVERIFY (directory.isValid ());
    QSettings settings {directory.filePath ("settings.ini"), QSettings::IniFormat};
    QCOMPARE (saved_samples_url (settings), QString {"https://wsjtx.github.io/wsjtx/"});
  }

  void saved_sourceforge_default_reads_as_pages ()
  {
    QTemporaryDir directory;
    QVERIFY (directory.isValid ());
    QSettings settings {directory.filePath ("settings.ini"), QSettings::IniFormat};
    settings.setValue ("SamplesURL", "http://downloads.sourceforge.net/project/wsjt/");
    QCOMPARE (saved_samples_url (settings), QString {"https://wsjtx.github.io/wsjtx/"});
  }

  void custom_url_is_kept ()
  {
    QTemporaryDir directory;
    QVERIFY (directory.isValid ());
    QSettings settings {directory.filePath ("settings.ini"), QSettings::IniFormat};
    settings.setValue ("SamplesURL", "https://mirror.example.org/wsjt/");
    QCOMPARE (saved_samples_url (settings), QString {"https://mirror.example.org/wsjt/"});
  }

  void default_url_is_not_saved ()
  {
    QTemporaryDir directory;
    QVERIFY (directory.isValid ());
    QSettings settings {directory.filePath ("settings.ini"), QSettings::IniFormat};
    settings.setValue ("SamplesURL", "http://downloads.sourceforge.net/project/wsjt/");
    save_samples_url (settings, "https://wsjtx.github.io/wsjtx/");
    QVERIFY (!settings.contains ("SamplesURL"));
  }

  void custom_url_is_saved ()
  {
    QTemporaryDir directory;
    QVERIFY (directory.isValid ());
    QSettings settings {directory.filePath ("settings.ini"), QSettings::IniFormat};
    save_samples_url (settings, "https://mirror.example.org/wsjt/");
    QCOMPARE (settings.value ("SamplesURL").toString (), QString {"https://mirror.example.org/wsjt/"});
  }

  void https_without_tls_reports_tls_required ()
  {
    QTemporaryDir directory;
    QVERIFY (directory.isValid ());
    NoTlsNetworkAccessManager network;
    QVERIFY (!network.supportedSchemes ().contains ("https"));
    Listener listener;
    RemoteFile file {&listener, &network, directory.filePath ("samples/contents_3.3.json")};
    file.sync (QUrl {"https://wsjtx.github.io/wsjtx/samples/contents_3.3.json"});
    QCOMPARE (network.requested, QList<QUrl> {});
    QCOMPARE (listener.finished, QList<bool> {false});
    QCOMPARE (listener.errors.size (), 1);
    QVERIFY2 (listener.errors.first ().contains ("SSL/TLS"), qPrintable (listener.errors.first ()));
    QVERIFY (!file.local ());
  }
};

QTEST_GUILESS_MAIN (TestSampleDownloader)

#include "test_sample_downloader.moc"
