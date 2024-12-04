import 'dart:async'; // 타이머를 위해 추가
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert'; // JSON 파싱을 위해 추가
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_sound/flutter_sound.dart' as sound;
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF2E9D7),
        textTheme: GoogleFonts.juaTextTheme(Theme.of(context).textTheme),
      ),
      home: Scaffold(
        body: SafeArea(
          child: MainPage(),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FlutterTts flutterTts = FlutterTts();
  bool isGuideAnnounced = false; // 음성 가이드 실행 여부
  final ImagePicker _picker = ImagePicker();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: Duration(milliseconds: 5000), // 5초 연결 타임아웃
      receiveTimeout: Duration(milliseconds: 30000), // 30초 수신 타임아웃
      headers: {
        "Content-Type": "multipart/form-data",
      },
      validateStatus: (status) {
        return status! < 500; // 4xx, 5xx 에러도 처리
      },
    ),
  );

  _MainPageState() {
    flutterTts.setLanguage("ko-KR");
    flutterTts.setEngine("com.google.android.tts");
    flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  @override
  void initState() {
    super.initState();
    if (!isGuideAnnounced) {
      _announceAppName(); // 처음 로드 시만 음성 가이드 실행
      isGuideAnnounced = true;
    }
  }

  Future<void> _announceAppName() async {
    await _speak("이 앱은 여기약입니다. 시각장애인의 복약환경 개선을 위한 여기약이 실행되었습니다. 여기약은 사진촬영을 통해 상비약과 처방약의 구분과 관리를 돕습니다. 화면을 터치하여 사용할 기능을 고르고, 다시 길게 누른 후 음성안내에 따라주세요. 모든 행동은 음성가이드가 끝난 후 진행해주세요.");
  }

  //처방약 먹기 사진 찍고 업로드
  Future<void> takePhotoAndUpload1(BuildContext context) async {
    try {
      await _speak("처방약 복용 카메라가 실행됩니다. 주변을 깨끗이 하고, 처방약 봉투를 찍어주세요. 화면을 두번 터치 후 찰칵 소리가 나면 오른쪽 아래 확인버튼을 눌러야 합니다.");
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        FormData formData = FormData.fromMap({
          "image": await MultipartFile.fromFile(photo.path, filename: "prescription.jpg"),
        });

        // 서버 요청
        final response = await _dio.post(
          'http://13.124.74.154:8080/prescription/process',
          data: formData,
          options: Options(headers: {"Content-Type": "multipart/form-data"}),
        );

        // 응답 처리
        if (response.statusCode == 200 && response.data != null) {
          final responseData = response.data is String
              ? json.decode(response.data)
              : response.data;

          if (responseData.containsKey('hospital_name') && responseData.containsKey('message')) {
            final hospitalName = responseData['hospital_name'];
            final extractedText = responseData['message']; // 텍스트를 다음 화면으로 전달

            await _speak("등록된 처방약 중에서 찾았습니다. $hospitalName병원 약입니다. $extractedText 약을 복용하시겠습니까? 맞다면 가운데를 꾹 눌러주시고, 아니라면 맨 아래를 눌러주세요.");
            // 다음 화면으로 전달
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrescriptionResultPage(
                  hospitalName: hospitalName,
                  extractedText: extractedText,
                ),
              ),
            );
          } else {
            _speak("등록된 처방약 중에서 병원 정보를 찾을 수 없습니다.");
          }
        } else {
          _speak("서버 응답이 올바르지 않습니다.");
        }
      } else {
        _speak("사진을 선택하지 않았습니다.");
      }
    } catch (e) {
      print("오류 발생: $e");
      _speak("서버에 연결할 수 없습니다.");
    }
  }

  //약 등록 시 사진 찍고 업로드
  Future<void> takePhotoAndUpload(BuildContext context) async {
    try {
      await _speak("약 등록 카메라가 실행됩니다. 처방약의 경우 처방약 봉투를, 상비약의 경우 상비약 상자를 찍어주세요. 화며을 두번 터치 후 찰칵 소리가 나면 오른쪽 아래 확인버튼을 눌러야 합니다.");
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        FormData formData = FormData.fromMap({
          "image": await MultipartFile.fromFile(photo.path, filename: "medicine.jpg"),
        });

        // 서버 요청
        final response = await _dio.post(
          'http://13.124.74.154:8080/combined/drug-registraion',
          data: formData,
          options: Options(
            headers: {
              "Content-Type": "multipart/form-data",
            },
          ),
        );


        // 응답 데이터 확인
        print("응답 데이터: ${response.data}");
        print("응답 헤더: ${response.headers}");
        print("응답 데이터 타입: ${response.data.runtimeType}");

        // 응답이 비어 있는 경우 처리
        if (response.data == null || response.data.toString().isEmpty) {
          _speak("서버에서 응답이 없습니다. 다시 시도해주세요.");
          print("서버 응답이 비어 있습니다.");
          return;
        }

        // 응답이 String으로 왔을 경우 JSON으로 변환
        final Map<String, dynamic> responseData = response.data is String
            ? json.decode(response.data)
            : response.data;

        // 응답 처리
        final status = responseData['status'];
        if (status == "success") {
          final name = responseData['name'] ?? "알 수 없는 이름";
          final message = responseData['message'] ?? "메시지가 없습니다.";
          _speak("약 등록이 완료되었습니다. 이름: $name. $message. 메인 페이지로 이동을 원하시면 맨 아래 버튼을 눌러주세요.");

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DrugInfoScreen(drugName: name),
            ),
          );
        } else if (status == "error") {
          final errorMessage = responseData['error_message'] ?? "알 수 없는 오류가 발생했습니다.";
          _speak("$errorMessage 사진을 다시 찍어주세요");

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Fail()),
          );

          Future.delayed(Duration(seconds: 3), () async {
            await _speak("메인페이지로 이동합니다");
            Navigator.pop(context); // Fail 화면에서 메인페이지로 돌아가기
          });
        } else {
          _speak("예상치 못한 응답을 받았습니다.");
        }
      } else {
        _speak("사진을 선택하지 않았습니다.");
      }
    } catch (e) {
      print("오류 발생: $e");
      _speak("서버에 연결할 수 없습니다.");
    }
  }

  // 상비약 조회 버튼 동작 구현
  Future<void> checkStockMedicine(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();
    final Dio _dio = Dio();
    final FlutterTts flutterTts = FlutterTts();

    flutterTts.setLanguage("ko-KR");
    flutterTts.setEngine("com.google.android.tts");
    flutterTts.setPitch(1.0);

    try {
      // 카메라 실행
      await _speak("상비약 이름확인을 위해 카메라가 실행됩니다. 화면을 두번 터치 후 찰칵 소리가 나면 오른쪽 아래 확인버튼을 눌러야 합니다.");
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        // FormData 생성
        FormData formData = FormData.fromMap({
          "image": await MultipartFile.fromFile(photo.path, filename: "medicine.jpg"),
        });

        // 서버 요청
        final response = await _dio.post(
          'http://13.124.74.154:8080/combined/medicine-check',
          data: formData,
          options: Options(
            headers: {"Content-Type": "multipart/form-data"},
          ),
        );

        // 응답 처리
        if (response.statusCode == 200 && response.data != null) {
          final status = response.data['status'];
          if (status == "success") {
            final medicineName = response.data['medicine_name'] ?? "알 수 없는 약";
            final message = response.data['message'] ?? "알 수 없는 메시지";
            final efficacy = response.data['efficacy'] ?? "효능/효과 정보가 없습니다.";

            final successMessage = "$medicineName 약의 정보입니다. $message. 효능 및 효과는 $efficacy.";
            await flutterTts.speak(successMessage);
          } else {
            final errorMessage =
                response.data['error_message'] ?? "처리 중 알 수 없는 오류가 발생했습니다.";
            await flutterTts.speak(errorMessage);
          }
        } else {
          await flutterTts.speak("서버 응답이 올바르지 않습니다.");
        }
      } else {
        await flutterTts.speak("사진이 선택되지 않았습니다.");
      }
    } catch (e) {
      await flutterTts.speak("서버에 연결할 수 없습니다. 오류: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double boxWidth = (size.width - 60) / 2;
    final double boxHeight = boxWidth * 1.2;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ClickableBoxWidget(
              title: "처방약\n복용",
              color: Color(0xFFFFD700),
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              onSingleTap: () async => await _speak("처방받은 약을 복용하기 위한 버튼입니다."),
              onLongPress: () async => await takePhotoAndUpload1(context),
              imagePath: "assets/imgs/drugpic1.png", // 이미지를 추가
              imageWidth: boxWidth * 0.5, // 너비를 박스 너비의 30%로 설정
              imageHeight: boxHeight * 0.45, // 높이를 박스 높이의 30%로 설정
            ),
            ClickableBoxWidget(
              title: "약\n등록",
              color: Color(0xFFFFFCF5),
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              onSingleTap: () async => await _speak("약을 등록하는 버튼입니다."),
              onLongPress: () async => await takePhotoAndUpload(context),
              imagePath: "assets/imgs/drugpic3.png", // 이미지를 추가
              imageWidth: boxWidth * 0.5, // 너비를 박스 너비의 30%로 설정
              imageHeight: boxHeight * 0.45, // 높이를 박스 높이의 30%로 설정
            ),
          ],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 150,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/imgs/mainlogo2.png"),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: 2),
            Text(
              '여기약',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 40,
                fontFamily: 'Jua',
                fontWeight: FontWeight.w400,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ClickableBoxWidget(
              title: "상비약 이름\n확인 &\n상비약 삭제",
              color: Color(0xFFFFFCF5),
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              onSingleTap: () async => await _speak("상비약 이름 확인 및 상비약 삭제 버튼입니다."),
              onLongPress: () {
                Future<void> _speak(String text) async {
                  await flutterTts.stop();
                  await flutterTts.speak(text);
                }
                _speak("상비약의 상자사진을 찍어 상비약 이름을 확인 및 상비약을 삭제합니다. 위쪽에 상비약 이름확인버튼, 아래쪽에 상비약을 삭제하는 버튼, 맨 아래에는 메인페이지로 이동하는 버튼이 있습니다.");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StockMedicineScreen()),
                );
              },
              imagePath: "assets/imgs/drugpic4.png", // 이미지를 추가
              imageWidth: boxWidth * 0.5, // 너비를 박스 너비의
              imageHeight: boxHeight * 0.4, // 높이를 박스 높이의
            ),
            ClickableBoxWidget(
              title: "효능효과로\n상비약\n검색",
              color: Color(0xFFFFD700),
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              onSingleTap: () async => await _speak("효능효과로 상비약 검색을 해주는 버튼입니다."),
              onLongPress: () {
                _speak("효능효과로 상비약울 검색합니다. 가운데를 꾹 눌러 증상을 음성으로 입력하세요. 가운데를 꾹 누르면 음성입력 시작, 손을 떼면 음성입력이 종료됩니다.");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SymptomInputScreen()),
                );
              },
              imagePath: "assets/imgs/drugpic5.png", // 이미지를 추가
              imageWidth: boxWidth * 0.45, // 너비를 박스 너비의
              imageHeight: boxHeight * 0.35, // 높이를 박스 높이의
            ),
          ],
        ),
      ],
    );
  }
}

//처방약 먹기 (처방전 업로드 후 결과 화면)
class PrescriptionResultPage extends StatelessWidget {
  final String hospitalName;
  final String extractedText;

  PrescriptionResultPage({required this.hospitalName, required this.extractedText});

  Future<void> _handleCameraAndUpload(BuildContext context) async {
    final Dio _dio = Dio();
    final ImagePicker picker = ImagePicker();

    try {
      await _speak("카메라가 실행됩니다. 처방약 개별봉투를 찍어주세요. 화면을 두번 터치 후 찰칵 소리가 나면 오른쪽 아래 확인버튼을 눌러야 합니다.");
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        await _speak("사진이 선택되지 않았습니다.");
        return;
      }

      await _speak("사진을 서버로 전송 중입니다.");

      FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(photo.path, filename: "prescription.jpg"),
      });

      // 서버 전송
      final response = await _dio.post(
        'http://13.124.74.154:8080/vision/extract-text',
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final status = response.data['status'];
        if (status == "success") {
          final extractedText = response.data['message'] ?? "알 수 없는 정보";
          await _speak("$extractedText약 입니다. 먹고 싶은 약이 아니라면 왼쪽 상단을 눌러주세요. 남은 약 봉투 개수를 확인하고 싶다면 가운데를 꾹 눌러주세요");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrescriptionTextExtractor(
                hospitalName: hospitalName, // 병원 이름 전달
                extractedText: extractedText, // 추출된 텍스트 전달
              ),
            ),
          );

        } else {
          final errorMessage = response.data['error_message'] ?? "오류 발생.";
          await _speak(errorMessage);
        }
      } else {
        await _speak("서버 응답이 올바르지 않습니다.");
      }
    } catch (e) {
      await _speak("서버 오류가 발생했습니다: $e");
    }
  }

  Future<void> _speak(String text) async {
    final FlutterTts flutterTts = FlutterTts();
    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6CECC),
      appBar: AppBar(
        title: Text("처방약 복용"),
        backgroundColor: Color(0xFF1C3462),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "처방 병원:",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    hospitalName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      await _speak("개별 약봉투를 활영하여 복용시기를 판별합니다.");
                    },
                    onLongPress: () async {
                      await _handleCameraAndUpload(context); // 카메라 실행 및 서버 전송 처리
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: 150,
                      margin: EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "네! 처방약 판별하러가기!",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: ElevatedButton(
              onPressed: () async {
                // 터치 시 음성 출력
                await _speak("메인페이지로 이동하는 버튼입니다.");
              },
              onLongPress: () async {
                // 길게 눌렀을 때 메인페이지로 이동
                await _speak("메인페이지로 이동합니다.");
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text("여기약 메인페이지"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1C3462),
                padding: EdgeInsets.symmetric(horizontal: 150, vertical: 40),
                textStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//처방약 먹기(남은약 봉투 개수 출력) PrescriptionTextExtractor
class PrescriptionTextExtractor extends StatefulWidget {
  final String hospitalName;
  final String extractedText;

  PrescriptionTextExtractor({
    required this.hospitalName,
    required this.extractedText,
  });

  @override
  _PrescriptionTextExtractorState createState() =>
      _PrescriptionTextExtractorState();
}

class _PrescriptionTextExtractorState extends State<PrescriptionTextExtractor> {
  final Dio _dio = Dio();
  final FlutterTts flutterTts = FlutterTts();
  String? totalBagsMessage;
  bool isPressed = false;

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("ko-KR");
    flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  Future<bool> _onWillPop() async {
    // 뒤로가기 버튼 클릭 시 음성 출력
    await _speak("이전 페이지로 이동합니다. 가운데를 길게 눌러 처방약 개별 봉투를 다시 찍어주세요");
    return true; // `true`를 반환하면 뒤로 가기 허용
  }

  Future<void> fetchPrescriptionCount() async {
    try {
      final formData = FormData.fromMap({
        "hospitalName": widget.hospitalName,
        "timeOfDay": widget.extractedText,
      });

      print("요청 데이터: $formData");

      final response = await _dio.post(
        'http://13.124.74.154:8080/prescription/update-dosage',
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final status = response.data['status'];

        if (status == "success") {
          final dosageMessage = response.data['message'];
          String totalBagsMessage =
              "남은 약 봉투는 ${response.data['remaining_bags']}개 입니다.";
          await _speak("$totalBagsMessage $dosageMessage");
        } else {
          final errorMessage = response.data['error_message'] ?? "오류 발생.";
          await _speak(errorMessage);
        }
      } else {
        await _speak("서버 응답이 올바르지 않습니다.");
      }
    } catch (e) {
      await _speak("오류 발생: 서버에 연결할 수 없습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: _onWillPop, // 뒤로 가기 동작을 제어
      child: Scaffold(
        appBar: AppBar(
          title: Text("처방 약 관리"),
          backgroundColor: Color(0xFF1C3462),
        ),
        backgroundColor: Color(0xFFF2E9D7),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "처방 병원: ${widget.hospitalName}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 20),
                    GestureDetector(
                      onLongPress: () async {
                        setState(() {
                          isPressed = true;
                        });
                        await fetchPrescriptionCount();
                        setState(() {
                          isPressed = false;
                        });
                      },
                      onLongPressEnd: (_) {
                        setState(() {
                          isPressed = false;
                        });
                      },
                      child: Container(
                        width: size.width * 0.8,
                        height: size.width * 0.5,
                        decoration: BoxDecoration(
                          color: Color(0xFF1C3462),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            isPressed ? "조회 중..." : "남은 약 봉투 확인",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: ElevatedButton(
                onPressed: () async {
                  await _speak("메인페이지로 이동하는 버튼입니다.");
                },
                onLongPress: () async {
                  await _speak("메인페이지로 이동합니다.");
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text("여기약 메인페이지"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1C3462),
                  padding: EdgeInsets.symmetric(horizontal: 150, vertical: 40),
                  textStyle: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

  void navigateToPrescriptionManager(
    BuildContext context,
    String hospitalName,
    String extractedText, // 추가된 매개변수
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PrescriptionTextExtractor(
        hospitalName: hospitalName,
        extractedText: extractedText, // 필수 매개변수 전달
      ),
    ),
  );
}


//서버로 증상 보내기
class SymptomInputScreen extends StatefulWidget {
  @override
  _SymptomInputScreenState createState() => _SymptomInputScreenState();
}

class _SymptomInputScreenState extends State<SymptomInputScreen> {
  final recorder = sound.FlutterSoundRecorder();
  final FlutterTts flutterTts = FlutterTts(); // FlutterTts 초기화 추가
  bool isRecording = false;
  String audioPath = '';
  String playAudioPath = '';
  final audioPlayer = AudioPlayer();
  bool isPlaying = false;
  List<String> recommendedMedicines = [];

  @override
  void initState() {
    super.initState();
    initRecorder();
    flutterTts.setLanguage("ko-KR"); // TTS 언어 설정 추가
    flutterTts.setPitch(1.0); // TTS 음성 피치 설정 추가
  }

  @override
  void dispose() {
    recorder.closeRecorder();
    audioPlayer.dispose();
    super.dispose();
  }

  // 음성 출력 메서드
  Future<void> _speak(String text) async {
    try {
      await flutterTts.awaitSpeakCompletion(true); // 음성 출력 대기 추가
      await flutterTts.speak(text);
    } catch (e) {
      print("음성 출력 오류 발생: $e"); // 오류 발생 시 로그 출력
    }
  }

  Future<void> initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw 'Microphone permission not granted';
    }
    await recorder.openRecorder();
  }

  Future<void> record() async {
    if (!isRecording) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await recorder.startRecorder(
        toFile: path,
        codec: sound.Codec.aacMP4,
      );

      setState(() {
        isRecording = true;
        audioPath = path;
      });
    }
  }

  Future<void> stop() async {
    final path = await recorder.stopRecorder();
    if (path != null) {
      audioPath = path;

      if (File(audioPath).existsSync()) {
        final savedPath = await saveRecordingLocally();
        if (savedPath.isNotEmpty) {
          await _speak("음성 녹음이 완료되었습니다."); // 먼저 음성 안내 출력
          await sendAudioToServer(savedPath); // 그 후 서버로 오디오 전송
        }
      } else {
        print("녹음 파일이 존재하지 않습니다.");
      }
    }

    setState(() {
      isRecording = false;
    });
  }

  Future<String> saveRecordingLocally() async {
    final audioFile = File(audioPath);
    if (!audioFile.existsSync()) return '';

    try {
      final directory = await getApplicationDocumentsDirectory();
      final newPath = p.join(directory.path, 'recordings', 'audio.m4a');
      await Directory(p.dirname(newPath)).create(recursive: true);
      await audioFile.copy(newPath);
      playAudioPath = newPath;
      return newPath;
    } catch (e) {
      print('녹음 파일 저장 중 오류: $e');
      return '';
    }
  }

  Future<void> playRecording() async {
    if (playAudioPath.isNotEmpty && File(playAudioPath).existsSync()) {
      await audioPlayer.setSourceDeviceFile(playAudioPath);
      await audioPlayer.resume();
    }
  }

  Future<void> sendAudioToServer(String filePath) async {
    try {
      // 파일 확인
      final file = File(filePath);
      if (!file.existsSync()) {
        print("오류: 파일이 존재하지 않습니다.");
        await _speak("파일이 존재하지 않습니다.");
        return;
      }

      // 파일 크기 확인
      final fileSize = await file.length();
      print("파일 크기: $fileSize bytes");

      if (fileSize == 0) {
        print("오류: 파일이 비어 있습니다.");
        await _speak("파일이 비어 있습니다.");
        return;
      }

      // FormData 생성
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: p.basename(filePath),
          contentType: MediaType.parse("audio/mp4"),
        ),
      });

      // 서버 요청
      final dio = Dio();
      final response = await dio.post(
        'http://13.124.74.154:8080/api/transcription-to-medicine',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      // 응답 처리
      if (response.statusCode == 200) {
        print('서버 응답: ${response.data}');
        final responseData = response.data;

        if (responseData['status'] == 'success') {
          // 변환된 텍스트 출력
          final transcriptionText = responseData['transcriptionText'];
          if (transcriptionText != null) {
            print('변환된 텍스트: $transcriptionText');
            await _speak("입력하신 증상은 $transcriptionText 입니다.");
          }

          // 추천 약 정보 처리
          if (responseData.containsKey('recommendedMedicines')) {
            final recommendedData = responseData['recommendedMedicines'];

            if (recommendedData['status'] == 'success' &&
                recommendedData['medicines'] is List) {
              final medicines = recommendedData['medicines'] as List<dynamic>;
              final medicineList = medicines.cast<String>();

              // 추천 약 목록 생성 및 음성 출력
              if (medicineList.isNotEmpty) {
                final medicineString = medicineList.join(", ");
                print('추천 약: $medicineString');
                await _speak("해당 증상의 효능효과와 일치하는 약은 $medicineString 입니다.");
              } else {
                print('추천 약 목록이 비어 있습니다.');
                await _speak("추천 약 목록이 없습니다.");
              }
            } else {
              print('추천 약 데이터가 올바르지 않습니다.');
              await _speak("해당 약을 상비약 목록에서 찾을 수 없습니다.");
            }
          }
        } else if (responseData['status'] == 'error') {
          // 에러 메시지 출력
          final errorMessage =
              responseData['error_message'] ?? "알 수 없는 오류가 발생했습니다.";
          print('오류 메시지: $errorMessage');
          await _speak(errorMessage);
        } else {
          print('알 수 없는 상태: ${responseData['status']}');
          await _speak("알 수 없는 상태입니다.");
        }
      } else {
        print('서버 요청 실패: ${response.statusCode}');
        await _speak("서버 요청이 실패했습니다.");
      }
    } catch (e) {
      print('오류 발생: $e');
      await _speak("서버 요청 중 오류가 발생했습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Color(0xFFF6ED5D),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '증상을\n음성으로\n입력해주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C3462),
                    ),
                  ),
                  SizedBox(height: 20),
                  GestureDetector(
                    onLongPress: record,
                    onLongPressUp: () async {
                      await stop(); // 녹음을 멈추는 메서드 호출 (음성 안내는 stop() 내부에서 실행)
                    },
                    child: Container(
                      width: size.width * 0.8,
                      height: size.width * 0.5,
                      decoration: BoxDecoration(
                        color: Color(0xFF1C3462),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Icon(
                          isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: playRecording,
                    child: Text(isPlaying ? "재생 중..." : "녹음 파일 재생"),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: ElevatedButton(
              onPressed: () async {
                await _speak("메인페이지로 이동하는 버튼입니다.");
              },
              onLongPress: () async {
                await _speak("메인페이지로 이동합니다.");
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text("여기약 메인페이지"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1C3462),
                padding: EdgeInsets.symmetric(horizontal: 150, vertical: 40),
                textStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}




//새로 추기 위젯(추천결과화면)
class DrugInfoCardAlt extends StatefulWidget {
  final String drugName;

  DrugInfoCardAlt({required this.drugName});

  @override
  _DrugInfoCardAltState createState() => _DrugInfoCardAltState();
}

class _DrugInfoCardAltState extends State<DrugInfoCardAlt> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speakDrugName(widget.drugName);
  }

  Future<void> _speakDrugName(String drugName) async {
    try {
      await flutterTts.setLanguage("ko-KR");
      await flutterTts.setPitch(1.0);
      await flutterTts.awaitSpeakCompletion(true); // 음성 출력을 대기
      await flutterTts.speak(drugName);
    } catch (e) {
      print("오류 발생: $e"); // 디버깅용 로그
    }
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      color: Color(0xFFF2E9D7), // 배경색
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 200),
          Container(
            width: size.width * 0.8,
            child: Text(
              widget.drugName,
              style: TextStyle(
                color: Colors.black,
                fontSize: 40,
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.left,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '증상 입력에 기반한 약 입니다.',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 20),
          Container(
            width: size.width * 0.6,
            height: size.width * 0.4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: Offset(5, 5),
                ),
              ],
              image: DecorationImage(
                image: AssetImage("assets/imgs/drugpic1.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Spacer(),
          GestureDetector(
            onTap: () async {
              await _speakDrugName("메인페이지로 이동합니다");
              Navigator.pop(context); // 메인 페이지로 이동
            },
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: size.width,
                height: size.width * 0.3,
                margin: EdgeInsets.only(bottom: 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '여기약 메인페이지',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'Jua',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}






// 오류 페이지를 나타내는 Fail 클래스
class Fail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6CECC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 207.80,
              height: 54.69,
              child: Text(
                '다시\n찍어주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1C3462),
                  fontSize: 30,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: 30),
            Container(
              width: 102,
              height: 105,
              decoration: ShapeDecoration(
                color: Color(0xFFF6CECC),
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 6, color: Color(0xFF1C3462)),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Center(
                child: Text(
                  '!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1C3462),
                    fontSize: 90,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// DrugInfoCard 위젯
class DrugInfoCard extends StatelessWidget {
  final String drugName;

  DrugInfoCard({required this.drugName});

  Future<void> _speak(String text, FlutterTts flutterTts) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final FlutterTts flutterTts = FlutterTts();

    flutterTts.setLanguage("ko-KR");
    flutterTts.setEngine("com.google.android.tts");
    flutterTts.setPitch(1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 200),
        Container(
          width: size.width * 0.8,
          child: Text(
            drugName,
            style: TextStyle(
              color: Colors.black,
              fontSize: 40,
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '등록이 완료되었습니다.',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontFamily: 'Inter',
          ),
        ),
        SizedBox(height: 20),
        Container(
          width: size.width * 0.6,
          height: size.width * 0.4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: Offset(5, 5),
              ),
            ],
            image: DecorationImage(
              image: AssetImage("assets/imgs/drugpic2.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Spacer(),
        GestureDetector(
          onTap: () async {
            // 한번 터치 시 음성 메시지만 출력
            await _speak("메인페이지로 이동하는 버튼입니다", flutterTts);
          },
          onLongPress: () async {
            // 길게 누를 시 음성 가이드와 함께 메인 페이지로 이동
            await _speak(
                "메인페이지로 이동합니다.",
                flutterTts);
            Navigator.of(context).popUntil((route) => route.isFirst); // 메인 페이지로 이동
          },
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: size.width,
              height: size.width * 0.3,
              margin: EdgeInsets.only(bottom: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '여기약 메인페이지',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontFamily: 'Jua',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// DrugInfoScreen 클래스
class DrugInfoScreen extends StatelessWidget {
  final String drugName;

  DrugInfoScreen({required this.drugName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2E9D7),
      body: DrugInfoCard(drugName: drugName),
    );
  }
}

// 재사용 가능한 Box 위젯으로 길게 눌렀을 때의 동작 추가
class ClickableBoxWidget extends StatelessWidget {
  final String title;
  final Color color;
  final double boxWidth;
  final double boxHeight;
  final VoidCallback onSingleTap;
  final VoidCallback onLongPress;
  final String? imagePath; // 이미지 경로 추가
  final double? imageWidth; // 이미지 너비 추가
  final double? imageHeight; // 이미지 높이 추가

  ClickableBoxWidget({
    required this.title,
    required this.color,
    required this.boxWidth,
    required this.boxHeight,
    required this.onSingleTap,
    required this.onLongPress,
    this.imagePath,
    this.imageWidth, // 선택적 이미지 너비
    this.imageHeight, // 선택적 이미지 높이
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSingleTap,
      onLongPress: onLongPress,
      child: Container(
        width: boxWidth,
        height: boxHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  title,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 23,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (imagePath != null) // 이미지가 있는 경우에만 렌더링
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    imagePath!,
                    width: imageWidth ?? boxWidth * 0.4, // 기본값 설정
                    height: imageHeight ?? boxHeight * 0.4, // 기본값 설정
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}



// 상비약 조회
Future<void> checkStockMedicine(BuildContext context) async {
  final ImagePicker _picker = ImagePicker();
  final Dio _dio = Dio();
  final FlutterTts flutterTts = FlutterTts();

  flutterTts.setLanguage("ko-KR");
  flutterTts.setEngine("com.google.android.tts");
  flutterTts.setPitch(1.0);

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }
  
  try {
    // 카메라 실행
    await _speak("상비약 조회를 위해 카메라가 실행됩니다. 화면을 두번 터치하여 찰칵 소리가 나면 오른쪽 아래 확인버튼을 눌러야 합니다.");
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      // FormData 생성
      FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(photo.path, filename: "medicine.jpg"),
      });

      // 서버 요청
      final response = await _dio.post(
        'http://13.124.74.154:8080/combined/medicine-check',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
        ),
      );

      // 응답 처리
      if (response.statusCode == 200 && response.data != null) {
        final status = response.data['status'];
        if (status == "success") {
          final medicineName = response.data['medicine_name'] ?? "알 수 없는 약";
          final message = response.data['message'] ?? "알 수 없는 메시지";
          final efficacy = response.data['efficacy'] ?? "효능/효과 정보가 없습니다.";

          final successMessage = "$medicineName 약의 정보입니다. 효능 및 효과는 $efficacy.";
          await flutterTts.speak(successMessage);
        } else {
          final errorMessage =
              response.data['error_message'] ?? "처리 중 알 수 없는 오류가 발생했습니다.";
          await flutterTts.speak(errorMessage);
        }
      } else {
        await flutterTts.speak("서버 응답이 올바르지 않습니다.");
      }
    } else {
      await flutterTts.speak("사진이 선택되지 않았습니다.");
    }
  } catch (e) {
    await flutterTts.speak("서버에 연결할 수 없습니다. 오류: $e");
  }
}

//상비약 삭제
Future<void> deleteStockMedicine(BuildContext context) async {
  final FlutterTts flutterTts = FlutterTts();
  final ImagePicker _picker = ImagePicker();
  final Dio _dio = Dio();

  flutterTts.setLanguage("ko-KR");
  flutterTts.setPitch(1.0);
  flutterTts.setEngine("com.google.android.tts");

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  try {
    // 카메라 실행
    await _speak("상비약 삭제를 위해 카메라가 실행됩니다. 화면을 두번 터치 후 찰칵 소리가 나면 오른쪽 아래 확인버튼을 눌러야 합니다.");
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      // FormData 생성
      FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(photo.path, filename: "delete_image.jpg"),
      });

      // 서버 요청
      final response = await _dio.post(
        'http://13.124.74.154:8080/medicine/delete-by-image',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
        ),
      );

      // 서버 응답 처리
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> responseData = response.data;

        if (responseData['status'] == "success") {
          final name = responseData['name'] ?? "알 수 없는 이름";
          final message = responseData['message'] ?? "메시지가 없습니다.";
          await _speak("상비약 삭제가 성공했습니다. 약 이름: $name, 메시지: $message.");
        } else if (responseData['status'] == "error") {
          final errorMessage =
              responseData['error_message'] ?? "처리 중 알 수 없는 오류가 발생했습니다.";
          await _speak(errorMessage);
        } else if (responseData['status'] == "not_found") {
          final name = responseData['name'] ?? "알 수 없는 이름";
          final message = responseData['message'] ?? "해당 약을 찾을 수 없습니다.";
          await _speak("삭제할 약을 찾을 수 없습니다. 약 이름: $name, 메시지: $message.");
        }
      } else {
        await _speak("서버 응답이 올바르지 않습니다.");
      }
    } else {
      await _speak("사진이 선택되지 않았습니다.");
    }
  } catch (e) {
    await _speak("서버에 연결할 수 없습니다. 오류: $e");
  }
}

// 상비약 조회 및 삭제 페이지에 수정된 삭제 기능 적용
class StockMedicineScreen extends StatelessWidget {
  final FlutterTts flutterTts = FlutterTts();

  StockMedicineScreen() {
    flutterTts.setLanguage("ko-KR");
    flutterTts.setPitch(1.0);
    flutterTts.setEngine("com.google.android.tts");
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6ED5D),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 위아래로 간격 조정
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _speak("상비약 이름 확인 버튼입니다.");
                    },
                    onLongPress: () async {
                      await checkStockMedicine(context); // 상비약 조회 기능 실행
                    },
                    child: Container(
                      width: 270,
                      height: 210,
                      decoration: ShapeDecoration(
                        color: Color(0x7FD9D9D9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '상비약\n이름확인',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1C3462),
                            fontSize: 30,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  GestureDetector(
                    onTap: () async {
                      await _speak("상비약 삭제 버튼입니다.");
                    },
                    onLongPress: () async {
                      await deleteStockMedicine(context); // 수정된 상비약 삭제 기능 실행
                    },
                    child: Container(
                      width: 270,
                      height: 210,
                      decoration: ShapeDecoration(
                        color: Color(0x7FD9D9D9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '상비약\n삭제',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1C3462),
                            fontSize: 30,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: ElevatedButton(
              onPressed: () async {
                // 터치 시 음성 출력
                await _speak("메인페이지로 이동하는 버튼입니다.");
              },
              onLongPress: () async {
                // 길게 눌렀을 때 메인페이지로 이동
                await _speak("메인페이지로 이동합니다.");
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text("여기약 메인페이지"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1C3462),
                padding: EdgeInsets.symmetric(horizontal: 150, vertical: 40),
                textStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
