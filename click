elementclass RateControl {
  $rates,$ht_rates|

  filter_tx :: FilterTX()

  input -> filter_tx -> output;
  rate_control :: Minstrel(OFFSET 4, RT $rates, RT_HT $ht_rates);
  filter_tx [1] -> [1] rate_control [1] -> Discard();
  input [1] -> rate_control -> [1] output;

};

rates :: AvailableRates(DEFAULT 2 4 11 22 12 18 24 36 48 72 96 108);
rates_ht :: AvailableRates(DEFAULT 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15);

re :: EmpowerResourceElements( 36/HT20/0 40/HT20 44/HT20 48/HT20 52/HT20 56/HT20 60/HT20 64/HT20 149/HT20 153/HT20 157/HT20 161/HT20 165/HT20);

ControlSocket("TCP", 7777);
ers :: EmpowerRXStats(EL el)

wifi_cl :: Classifier(0/08%0c,  // data
                      0/00%0c); // mgt

ers -> wifi_cl;

switch_mngt :: PaintSwitch();
switch_data :: PaintSwitch();

rc_0 :: RateControl(rates, rates_ht);

FromDevice(moni0, PROMISC false, OUTBOUND true, SNIFFER false)
  -> RadiotapDecap()
  -> FilterPhyErr()
  -> rc_0
  -> WifiDupeFilter()
  -> Paint(0)
  -> ers;

sched_0 :: PrioSched()
  -> WifiSeq()
  -> [1] rc_0 [1]
  -> SetChannel(CHANNEL 5180)
  -> RadiotapEncap()
  -> ToDevice (moni0);

switch_mngt[0]
  -> Queue(50)
  -> [0] sched_0;

switch_data[0]
  -> Queue()
  -> [1] sched_0;

FromHost(empower0)
  -> wifi_encap :: EmpowerWifiEncap(EL el,
                      DEBUG false)
  -> switch_data;

ctrl :: Socket(TCP, 10.123.0.254, 4433, CLIENT true, VERBOSE true, RECONNECT_CALL el.reconnect)
    -> downlink :: Counter()
    -> el :: EmpowerLVAPManager(HWADDRS " 04:18:D6:60:81:68",
                                WTP 04:18:D6:61:81:68,
                                EBS ebs,
                                EAUTHR eauthr,
                                EASSOR eassor,
				RE re,
                                RCS " rc_0/rate_control",
                                PERIOD 5000,
                                DEBUGFS " /sys/kernel/debug/ieee80211/phy0/ath9k/bssid_extra",
                                ERS ers,
                                UPLINK uplink,
                                DOWNLINK downlink,
                                DEBUG false)
    -> uplink :: Counter()
    -> ctrl;

  wifi_cl [0]
    -> wifi_decap :: EmpowerWifiDecap(EL el,
                        DEBUG false)
    -> ToHost(empower0);

  wifi_decap [1] -> wifi_encap;

  wifi_cl [1]
    -> mgt_cl :: Classifier(0/40%f0,  // probe req
                            0/b0%f0,  // auth req
                            0/00%f0,  // assoc req
                            0/20%f0,  // reassoc req
                            0/c0%f0,  // deauth
                            0/a0%f0); // disassoc

  mgt_cl [0]
    -> ebs :: EmpowerBeaconSource(RT rates,
                                  RT_HT rates_ht,
                                  EL el,
                                  PERIOD 100,
                                  DEBUG false)
    -> switch_mngt;

  mgt_cl [1]
    -> eauthr :: EmpowerOpenAuthResponder(EL el, DEBUG false)
    -> switch_mngt;

  mgt_cl [2]
    -> eassor :: EmpowerAssociationResponder(RT rates,
                                             RT_HT rates_ht,
                                             EL el,
                                             DEBUG false)
    -> switch_mngt;

  mgt_cl [3]
    -> eassor;

  mgt_cl [4]
    -> EmpowerDeAuthResponder(EL el, DEBUG false)
    -> Discard();

  mgt_cl [5]
    ->  EmpowerDisassocResponder(EL el, DEBUG false)
    ->Discard();
