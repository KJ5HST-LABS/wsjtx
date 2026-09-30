#include "wsjtx_config.h"
#include <QtTest>
#include <QTemporaryDir>

// Exercise the private dialog and its auto-connected slots without exposing a test API.
#include "Configuration.cpp"
#include "widgets/itoneAndicw.h"

int volatile itone[MAX_NUM_SYMBOLS] {};
float gran () { return 0; }

class TestConfigurationRadio final : public QObject
{
  Q_OBJECT

  using RadioValidationError = Configuration::impl::RadioValidationError;

  QTemporaryDir directory_;
  QNetworkAccessManager network_;
  std::unique_ptr<QSettings> settings_;
  std::unique_ptr<Configuration> configuration_;
  QString serial_rig_;
  QString network_rig_;

  Configuration::impl& dialog () { return *configuration_->m_; }
  Ui::configuration_dialog& ui () { return *dialog ().ui_; }

private slots:
  void initTestCase ()
  {
    register_types ();
    QStandardPaths::setTestModeEnabled (true);
    QCoreApplication::setApplicationName ("test_configuration_radio");
    QVERIFY (directory_.isValid ());
  }

  void init ()
  {
    settings_.reset (new QSettings {directory_.filePath ("settings.ini"), QSettings::IniFormat});
    settings_->clear ();
    configuration_.reset (new Configuration {&network_, QDir {directory_.path ()}, settings_.get (), nullptr});
    auto& d = dialog ();
    auto& rigs = const_cast<TransceiverFactory::Transceivers&> (d.transceiver_factory_.supported_transceivers ());
    using Caps = TransceiverFactory::Capabilities;
    for (auto it = rigs.cbegin (); it != rigs.cend (); ++it)
      {
        if (it->port_type_ == Caps::serial) serial_rig_ = it.key ();
        if (it->port_type_ == Caps::network) network_rig_ = it.key ();
      }
    QVERIFY (!serial_rig_.isEmpty ());
    QVERIFY (!network_rig_.isEmpty ());
    // OmniRig's Windows COM transport is unavailable here; use its registered capabilities.
    if (!rigs.contains ("OmniRig Rig 1"))
      rigs.insert ("OmniRig Rig 1", Caps {99904, Caps::none, true, false, true, true});
    d.enumerate_rigs ();
    d.rig_params_.rig_name = serial_rig_;
    d.rig_params_.serial_port = "/dev/test-cat";
    d.rig_params_.network_port = "localhost:4532";
    d.rig_params_.ptt_port = "/dev/test-cat";
    d.rig_params_.ptt_type = TransceiverFactory::PTT_method_DTR;
    d.rig_params_.handshake = TransceiverFactory::handshake_none;
    d.initialize_models ();
    // Audio availability is independent of these radio validation cases.
    if (ui ().sound_input_combo_box->currentIndex () < 0)
      ui ().sound_input_combo_box->addItem ("Test input");
    if (ui ().sound_input_channel_combo_box->currentIndex () < 0)
      ui ().sound_input_channel_combo_box->addItem ("Mono");
    if (ui ().sound_output_combo_box->currentIndex () < 0)
      ui ().sound_output_combo_box->addItem ("Test output");
    if (d.dns_lookup_id_ > -1) QHostInfo::abortHostLookup (d.dns_lookup_id_);
    d.dns_lookup_id_ = -1;
  }

  void cleanup ()
  {
    configuration_.reset ();
    settings_.reset ();
  }

  void proxyCatBecomesExplicitSerialSelection_data ()
  {
    QTest::addColumn<bool> ("rts");
    QTest::newRow ("DTR") << false;
    QTest::newRow ("RTS") << true;
  }

  void proxyCatBecomesExplicitSerialSelection ()
  {
    QFETCH (bool, rts);
    auto& u = ui ();
    u.rig_combo_box->setCurrentText ("OmniRig Rig 1");
    (rts ? u.PTT_RTS_radio_button : u.PTT_DTR_radio_button)->setChecked (true);
    u.PTT_port_combo_box->setCurrentIndex (u.PTT_port_combo_box->findText ("CAT"));
    QCOMPARE (u.PTT_port_combo_box->currentText (), QString {"CAT"});
    QCOMPARE (dialog ().validate_radio_settings (), RadioValidationError::none);
    QSignalSpy changes {u.PTT_port_combo_box, &QComboBox::currentTextChanged};
    u.rig_combo_box->setCurrentText (serial_rig_);
    QCOMPARE (u.PTT_port_combo_box->currentText (), QString {});
    QCOMPARE (u.PTT_port_combo_box->currentIndex (), -1);
    QCOMPARE (changes.count (), 0);
    QCOMPARE (u.PTT_port_combo_box->findText ("USB"), -1);
    QVERIFY (u.CAT_port_combo_box->findText ("USB") >= 0);
    for (int i = 0; i != 3; ++i) dialog ().set_rig_invariants ();
    QCOMPARE (u.PTT_port_combo_box->currentText (), QString {});
    u.rig_combo_box->setCurrentText ("OmniRig Rig 1");
    QCOMPARE (u.PTT_port_combo_box->currentText (), QString {});
    u.rig_combo_box->setCurrentText (serial_rig_);
    QCOMPARE (u.PTT_port_combo_box->currentText (), QString {});
    QCOMPARE (dialog ().validate_radio_settings (), RadioValidationError::invalid_ptt_port);
    u.PTT_port_combo_box->setEditText ("/dev/manually-entered-ptt");
    QCOMPARE (dialog ().validate_radio_settings (), RadioValidationError::none);
    QCOMPARE (dialog ().gather_rig_data ().ptt_port, QString {"/dev/manually-entered-ptt"});
  }

  void networkToSerialUsesFinalPorts_data ()
  {
    QTest::addColumn<bool> ("same_port");
    QTest::addColumn<bool> ("hardware");
    QTest::addColumn<bool> ("rts");
    for (bool same : {false, true})
      for (bool hw : {false, true})
        for (bool rts : {false, true})
          QTest::newRow (qPrintable (QString {"same=%1,hardware=%2,rts=%3"}.arg (same).arg (hw).arg (rts)))
            << same << hw << rts;
  }

  void networkToSerialUsesFinalPorts ()
  {
    QFETCH (bool, same_port);
    QFETCH (bool, hardware);
    QFETCH (bool, rts);
    auto& u = ui ();
    (hardware ? u.CAT_handshake_hardware_radio_button : u.CAT_handshake_none_radio_button)->setChecked (true);
    (rts ? u.PTT_RTS_radio_button : u.PTT_DTR_radio_button)->setChecked (true);
    u.PTT_port_combo_box->setEditText (same_port ? "/dev/test-cat" : "/dev/test-ptt");
    for (int i = 0; i != 3; ++i)
      {
        u.rig_combo_box->setCurrentText (network_rig_);
        QVERIFY (u.PTT_RTS_radio_button->isEnabled ());
        u.rig_combo_box->setCurrentText (serial_rig_);
        QCOMPARE (u.CAT_port_combo_box->currentText (), QString {"/dev/test-cat"});
        QCOMPARE (u.PTT_RTS_radio_button->isEnabled (), !(same_port && hardware));
        QCOMPARE (u.force_DTR_combo_box->isEnabled (), !(same_port && !rts));
        QCOMPARE (u.force_RTS_combo_box->isEnabled (), !hardware && !(same_port && rts));
        dialog ().set_rig_invariants ();
        QCOMPARE (u.PTT_RTS_radio_button->isEnabled (), !(same_port && hardware));
        QCOMPARE (u.force_DTR_combo_box->isEnabled (), !(same_port && !rts));
        QCOMPARE (u.force_RTS_combo_box->isEnabled (), !hardware && !(same_port && rts));
      }
  }

  void editablePortsUpdateWithoutActivation ()
  {
    auto& u = ui ();
    QSignalSpy activated {u.PTT_port_combo_box, QOverload<int>::of (&QComboBox::activated)};
    QVERIFY (!u.force_DTR_combo_box->isEnabled ());
    u.PTT_port_combo_box->lineEdit ()->selectAll ();
    QTest::keyClicks (u.PTT_port_combo_box->lineEdit (), "/dev/typed-port");
    QCOMPARE (activated.count (), 0);
    QVERIFY (u.force_DTR_combo_box->isEnabled ());
    u.CAT_port_combo_box->setEditText ("/dev/typed-port");
    QVERIFY (!u.force_DTR_combo_box->isEnabled ());
    u.CAT_handshake_hardware_radio_button->setChecked (true);
    QVERIFY (!u.PTT_RTS_radio_button->isEnabled ());
    u.PTT_port_combo_box->setCurrentText ("/dev/separate-port");
    QVERIFY (u.PTT_RTS_radio_button->isEnabled ());
    QVERIFY (!u.force_RTS_combo_box->isEnabled ());
  }

  void validationRefreshesBlockedProgrammaticChanges_data ()
  {
    QTest::addColumn<QString> ("port");
    QTest::newRow ("unsupported proxy") << QString {"CAT"};
    QTest::newRow ("USB is not serial PTT") << QString {"USB"};
    QTest::newRow ("empty") << QString {};
    QTest::newRow ("whitespace") << QString {"   "};
  }

  void validationRefreshesBlockedProgrammaticChanges ()
  {
    QFETCH (QString, port);
    auto& u = ui ();
    {
      QSignalBlocker blocked {u.PTT_port_combo_box};
      u.PTT_port_combo_box->setEditText (port);
    }
    QCOMPARE (dialog ().validate_radio_settings (), RadioValidationError::invalid_ptt_port);
    QVERIFY (!dialog ().rig_active_);
    QCOMPARE (dialog ().rig_params_.ptt_port, QString {"/dev/test-cat"});
  }

  void cancelRestoresSavedPorts ()
  {
    auto& u = ui ();
    u.CAT_port_combo_box->setEditText ("/dev/edited-cat");
    u.PTT_port_combo_box->setEditText ("/dev/edited-ptt");
    u.configuration_dialog_button_box->button (QDialogButtonBox::Cancel)->click ();
    QCOMPARE (u.CAT_port_combo_box->currentText (), QString {"/dev/test-cat"});
    QCOMPARE (u.PTT_port_combo_box->currentText (), QString {"/dev/test-cat"});
    QVERIFY (!u.force_DTR_combo_box->isEnabled ());
  }

  void validationRefreshesHandshakeAfterBlockedRigChange ()
  {
    auto& u = ui ();
    u.rig_combo_box->setCurrentText (network_rig_);
    u.CAT_handshake_hardware_radio_button->setChecked (true);
    u.PTT_RTS_radio_button->setChecked (true);
    QVERIFY (u.PTT_RTS_radio_button->isEnabled ());
    {
      QSignalBlocker blocked {u.rig_combo_box};
      u.rig_combo_box->setCurrentText (serial_rig_);
    }
    QCOMPARE (dialog ().validate_radio_settings (), RadioValidationError::invalid_ptt_method);
    QCOMPARE (u.CAT_port_combo_box->currentText (), u.PTT_port_combo_box->currentText ());
    QVERIFY (!u.PTT_RTS_radio_button->isEnabled ());
    QVERIFY (!u.force_RTS_combo_box->isEnabled ());
  }

  void noneRetainsSerialPortSelection ()
  {
    auto& u = ui ();
    u.CAT_port_combo_box->setEditText ("/dev/edited-cat");
    u.rig_combo_box->setCurrentText ("None");
    u.rig_combo_box->setCurrentText (serial_rig_);
    QCOMPARE (u.CAT_port_combo_box->currentText (), QString {"/dev/edited-cat"});
  }

  void destructionCancelsDeferredFileInformation ()
  {
    configuration_.reset ();
    QTest::qWait (3000);
  }
};

QTEST_MAIN (TestConfigurationRadio)
#include "test_configuration_radio.moc"
