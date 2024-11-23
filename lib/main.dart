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

  //처방약 먹기 사진 찍고 업로드
  Future<void> takePhotoAndUpload1(BuildContext context) async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        FormData formData = FormData.fromMap({
          "image": await MultipartFile.fromFile(photo.path, filename: "prescription.jpg"),
        });

        // 서버 요청
        final response = await _dio.post(
          'http://13.124.74.154:8080/prescription/process',
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
        if (responseData.containsKey('hospital_name')) {
          final hospitalName = responseData['hospital_name'] ?? "알 수 없는 병원";
          final hospitalmessage = responseData['message'] ?? "알 수 없는 병원약 정보";

          // 음성 출력 및 UI 업데이트
          await _speak("등록된 처방약 중에서 찾았습니다. $hospitalName병원 약입니다. $hospitalmessage 약을 복용하시겠습니까? 맞다면 가운데를 꾹 눌러주시고, 아니라면 맨 아래를 눌러주세요.");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrescriptionResultPage(hospitalName: hospitalName),
            ),
          );
        } else {
          _speak("등록된 처방약 중에서 병원 이름을 찾을 수 없습니다.");
          print("서버 응답에 병원 이름이 없습니다.");
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
          _speak("약 등록이 완료되었습니다. 이름: $name, 메시지: $message");

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DrugInfoScreen(drugName: name),
            ),
          );
        } else if (status == "error") {
          final errorMessage = responseData['error_message'] ?? "알 수 없는 오류가 발생했습니다.";
          _speak("오류가 발생했습니다: $errorMessage");

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
              onSingleTap: () async => await _speak("처방받은 약을 복용합니다"),
              onLongPress: () async => await takePhotoAndUpload1(context),
            ),
            ClickableBoxWidget(
              title: "약\n등록",
              color: Color(0xFFFFFCF5),
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              onSingleTap: () async => await _speak("약을 등록합니다"),
              onLongPress: () async => await takePhotoAndUpload(context),
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
              title: "상비약\n조회 및 삭제",
              color: Color(0xFFFFFCF5),
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              onSingleTap: () async => await _speak("상비약을 조회 및 삭제합니다"),
              onLongPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StockMedicineScreen()),
                );
              },
            ),
            ClickableBoxWidget(
              title: "상비약\n리스트업\n(추천)",
              color: Color(0xFFFFD700),
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              onSingleTap: () async => await _speak("상비약 리스트업 추천합니다"),
              onLongPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SymptomInputScreen()),
                );
              },
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

  PrescriptionResultPage({required this.hospitalName});

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
                    onLongPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrescriptionTextExtractor(),
                        ),
                      );
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
                          "네 ! 개별약 판별하러 가기 !",
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
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("여기약"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1C3462),
                padding: EdgeInsets.symmetric(horizontal: 150, vertical: 40),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


//처방약 먹기(아침, 점심, 저녁 구분)
class PrescriptionTextExtractor extends StatefulWidget {
  @override
  _PrescriptionTextExtractorState createState() => _PrescriptionTextExtractorState();
}

class _PrescriptionTextExtractorState extends State<PrescriptionTextExtractor> {
  final ImagePicker _picker = ImagePicker();
  final Dio _dio = Dio();
  String? extractedText;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("ko-KR");
    flutterTts.setEngine("com.google.android.tts");
    flutterTts.setPitch(1.0);
    captureAndExtractText(); // 화면 시작 시 카메라 실행
  }

  Future<void> captureAndExtractText() async {
    try {
      // 카메라 실행
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        // 서버로 사진 전송
        FormData formData = FormData.fromMap({
          "image": await MultipartFile.fromFile(photo.path, filename: "medicine.jpg"),
        });

        final response = await _dio.post(
          'http://13.124.74.154:8080/vision/extract-text',
          data: formData,
          options: Options(headers: {"Content-Type": "multipart/form-data"}),
        );

        // 응답 처리
        if (response.statusCode == 200 && response.data != null) {
          final text = response.data['extracted_text'] ?? "텍스트를 추출하지 못했습니다.";
          setState(() {
            extractedText = text;
          });
          await _speak(text); // 음성 출력
        } else {
          const errorText = "서버 응답이 없습니다.";
          setState(() {
            extractedText = errorText;
          });
          await _speak(errorText); // 음성 출력
        }
      } else {
        const noPhotoText = "사진을 선택하지 않았습니다.";
        setState(() {
          extractedText = noPhotoText;
        });
        await _speak(noPhotoText); // 음성 출력
      }
    } catch (e) {
      final errorText = "오류가 발생했습니다: $e";
      setState(() {
        extractedText = errorText;
      });
      await _speak(errorText); // 음성 출력
    }
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text("처방 개별약 판별"),
        backgroundColor: Color(0xFF1C3462),
      ),
      backgroundColor: Color(0xFFF2E9D7),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Center(
              child: extractedText == null
                  ? CircularProgressIndicator() // 처리 중
                  : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  extractedText!,
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
          Expanded(
            flex: 2,
            child: Center(
              child: GestureDetector(
                onLongPress: () async {
                  await _speak("약이 한 봉투 제거되었습니다."); // 길게 누를 시 hospitaltotal_bags 음성 출력
                },
                child: Container(
                  width: size.width * 0.8,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color(0xFFF6CECC), // 박스 색상
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "네 약을 복용합니다",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: ElevatedButton(
              onPressed: () async {
                await _speak("메인페이지로 이동합니다");
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => App()), // 메인 페이지로 이동
                      (route) => false, // 모든 경로 제거
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1C3462), // 버튼 색상
                padding: EdgeInsets.symmetric(horizontal: 150, vertical: 40),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text("여기약"),
            ),
          ),
        ],
      ),
    );
  }
}






//증상 추천 음성입력
class SymptomInputScreen extends StatefulWidget {
  @override
  _SymptomInputScreenState createState() => _SymptomInputScreenState();
}

class _SymptomInputScreenState extends State<SymptomInputScreen> {
  bool _isPressed = false; // 꾹 눌렀는지 여부
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speakInstruction();
  }

  Future<void> _speakInstruction() async {
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak("가운데를 꾹 눌러 증상을 음성으로 입력하세요");
  }

  void _navigateToNextPage(BuildContext context) {
    Future.delayed(Duration(seconds: 3), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DrugInfoCardAlt(drugName: "타이레놀 이부프로펜"),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Color(0xFFF6ED5D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '증상을\n음성으로\n입력해주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1C3462),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onLongPressStart: (_) {
                setState(() {
                  _isPressed = true; // 꾹 눌렀을 때 상태 변경
                });
              },
              onLongPressEnd: (_) {
                setState(() {
                  _isPressed = false; // 꾹 누름 해제 시 상태 변경
                });

                // 3초 후 페이지 전환
                _navigateToNextPage(context);
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
                    _isPressed ? "입력 중..." : '여기를 꾹 눌러 음성입력 시작',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              _isPressed ? "입력 중..." : "음성입력 대기 중",
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
          ],
        ),
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
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(drugName);
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
                    '여기약',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 25,
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
            await _speak("메인페이지로 이동합니다", flutterTts);
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
                  '여기약',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
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

  ClickableBoxWidget({
    required this.title,
    required this.color,
    required this.boxWidth,
    required this.boxHeight,
    required this.onSingleTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSingleTap,
      onLongPress: onLongPress, // 길게 눌렀을 때 실행
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
        child: Align(
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
      ),
    );
  }
}

// 상비약 조회 및 삭제 페이지 예시
class StockMedicineScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6ED5D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
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
                  '상비약\n조회',
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
            SizedBox(height: 30),
            Container(
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
          ],
        ),
      ),
    );
  }
}