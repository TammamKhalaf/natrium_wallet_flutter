import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:kalium_wallet_flutter/colors.dart';
import 'package:kalium_wallet_flutter/dimens.dart';
import 'package:kalium_wallet_flutter/styles.dart';
import 'package:kalium_wallet_flutter/kalium_icons.dart';
import 'package:kalium_wallet_flutter/ui/widgets/buttons.dart';
import 'package:kalium_wallet_flutter/ui/widgets/sheets.dart';
import 'package:kalium_wallet_flutter/ui/util/ui_util.dart';
import 'package:kalium_wallet_flutter/ui/receive/share_card.dart';
import 'package:kalium_wallet_flutter/model/wallet.dart';
import 'package:kalium_wallet_flutter/appstate_container.dart';
import 'package:qr/qr.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart';

class KaliumReceiveSheet {
  KaliumWallet _wallet;

  GlobalKey shareCardKey;
  Widget kaliumShareCard;
  ByteData shareImageData;
  Widget monkeySVGBorder;
  Widget shareCardLogoSvg;
  Widget shareCardTickerSvg;

  KaliumReceiveSheet() {
    // Create our SVG-heavy things in the constructor because they are slower operations
    monkeySVGBorder = SvgPicture.asset('assets/monkeyQR.svg');
    shareCardLogoSvg = SvgPicture.asset('assets/sharecard_bananologo.svg');
    shareCardTickerSvg = SvgPicture.asset('assets/sharecard_tickerwebsite.svg');
    // Share card initialization
    shareCardKey = GlobalKey();
    kaliumShareCard = Container(
      child: KaliumShareCard(shareCardKey, monkeySVGBorder, shareCardLogoSvg, shareCardTickerSvg),
      alignment: Alignment(0.0, 0.0),
    );
  }

  // Address copied items
  // Initial constants
  static const String _copyAddress = 'Copy Address';
  static const String _addressCopied = 'Address Copied';
  static const TextStyle _copyButtonStyleInitial =
      KaliumStyles.TextStyleButtonPrimary;
  static const Color _copyButtonColorInitial = KaliumColors.primary;
  // Current state references
  String _copyButtonText;
  TextStyle _copyButtonStyle;
  Color _copyButtonBackground;
  bool _showShareCard;
  // Timer reference so we can cancel repeated events
  Timer _addressCopiedTimer;

  Future<ByteData> _capturePng() async {
    if (shareCardKey != null && shareCardKey.currentContext != null) {
      RenderRepaintBoundary boundary =
          shareCardKey.currentContext.findRenderObject();
      ui.Image image = await boundary.toImage(pixelRatio: 25.0);
      ByteData byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData;
    } else {
      return null;
    }
  }

  mainBottomSheet(BuildContext context) {
    _wallet = StateContainer.of(context).wallet;
    // Set initial state of copy button
    _copyButtonText = _copyAddress;
    _copyButtonStyle = _copyButtonStyleInitial;
    _copyButtonBackground = _copyButtonColorInitial;
    double devicewidth = MediaQuery.of(context).size.width;

    _showShareCard = false;

    KaliumSheets.showKaliumHeightEightSheet(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    //Close Button
                    Container(
                      width: 50,
                      height: 50,
                      margin: EdgeInsets.only(top: 10.0, left: 10.0),
                      child: FlatButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Icon(KaliumIcons.close,
                            size: 16, color: KaliumColors.text),
                        padding: EdgeInsets.all(17.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100.0)),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                    ),

                    //Container for the address text
                    Container(
                      margin: EdgeInsets.only(top: 30.0),
                      child: UIUtil.threeLineAddressText(_wallet.address,
                          type: ThreeLineAddressTextType.PRIMARY60),
                    ),
                    //Empty SizedBox
                    SizedBox(
                      width: 60,
                      height: 60,
                    ),
                  ],
                ),

                //MonkeyQR which takes all the available space left from the buttons & address text
                Expanded(
                  child: Center(
                    child: Stack(
                      children: <Widget>[
                        _showShareCard ? kaliumShareCard : SizedBox(),
                        Center(
                          child: Container(
                            width: 260,
                            height: 150,
                            color: KaliumColors.backgroundDark,
                          ),
                        ),
                        Center(
                          child: Container(
                            width: devicewidth / 1.5,
                            child: monkeySVGBorder,
                          ),
                        ),
                        Center(
                          child: Container(
                            margin: EdgeInsets.only(top: devicewidth / 6),
                            child: QrImage(
                              padding: EdgeInsets.all(0.0),
                              size: devicewidth / 3.13,
                              data: _wallet.address,
                              version: 6,
                              errorCorrectionLevel: QrErrorCorrectLevel.Q,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                //A column with "Scan QR Code" and "Send" buttons
                Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.fromLTRB(
                                Dimens.BUTTON_TOP_DIMENS[0],
                                Dimens.BUTTON_TOP_DIMENS[1],
                                Dimens.BUTTON_TOP_DIMENS[2],
                                Dimens.BUTTON_TOP_DIMENS[3]),
                            child: FlatButton(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100.0)),
                              color: _copyButtonBackground,
                              child: Text(_copyButtonText,
                                  textAlign: TextAlign.center,
                                  style: _copyButtonStyle),
                              padding: EdgeInsets.symmetric(
                                  vertical: 14.0, horizontal: 20),
                              onPressed: () {
                                Clipboard.setData(
                                    new ClipboardData(text: _wallet.address));
                                setState(() {
                                  // Set copied style
                                  _copyButtonText = _addressCopied;
                                  _copyButtonStyle =
                                      KaliumStyles.TextStyleButtonPrimaryGreen;
                                  _copyButtonBackground = KaliumColors.green;
                                  if (_addressCopiedTimer != null) {
                                    _addressCopiedTimer.cancel();
                                  }
                                  _addressCopiedTimer = new Timer(
                                      const Duration(milliseconds: 800), () {
                                    setState(() {
                                      _copyButtonText = _copyAddress;
                                      _copyButtonStyle =
                                          _copyButtonStyleInitial;
                                      _copyButtonBackground =
                                          _copyButtonColorInitial;
                                    });
                                  });
                                });
                              },
                              highlightColor: KaliumColors.success30,
                              splashColor: KaliumColors.successDark,
                            ),
                          ),
                        )
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        KaliumButton.buildKaliumButton(
                            KaliumButtonType.PRIMARY_OUTLINE,
                            _showShareCard ? "Loading" : 'Share Address',
                            Dimens.BUTTON_BOTTOM_DIMENS, disabled: _showShareCard,
                             onPressed: () {
                          setState(() {
                            _showShareCard = true;
                          });
                          Future.delayed(new Duration(milliseconds: 200), () {
                            if (_showShareCard) {
                              _capturePng().then((byteData) {
                                if (byteData != null) {
                                  EsysFlutterShare.shareImage(
                                      "${StateContainer.of(context).wallet.address}.png",
                                      byteData,
                                      "Share Via...");
                                } else {
                                  // TODO - show a something went wrong message
                                }
                                setState(() {
                                  _showShareCard = false;
                                });
                              });
                            }
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ],
            );
          });
        });
  }
}
