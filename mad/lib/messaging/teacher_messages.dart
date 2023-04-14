import "package:chat_bubbles/chat_bubbles.dart";
import 'package:flutter/material.dart';
import "package:cloud_firestore/cloud_firestore.dart";
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Initializes Firebase database
var db = FirebaseFirestore.instance;

// This widget will display the message page for the teacher with a particular student.
// The teacher can either text the student or add an image.
class TeacherMessagesPage extends StatefulWidget {
  const TeacherMessagesPage({
    Key? key,
    required this.className,
    required this.teacher,
    required this.studentID,
    required this.isClass,
  }) : super(key: key);

  final String className;
  final String teacher;
  final String studentID;
  final bool isClass;

  @override
  State<TeacherMessagesPage> createState() => _TeacherMessagesPageState();
}

class _TeacherMessagesPageState extends State<TeacherMessagesPage> {
  // The controller contains the message that the user types.
  final TextEditingController _textController = TextEditingController();

  // The scroll controller ensures that the screen automatically scrolls down when the
  // user has typed a message.
  final ScrollController _scrollController = ScrollController();

  // This file contains an image that the user chooses from the image picker.
  File? imageFile;

  // This is the file name of the image picked
  String fileName = "";

  // This is the url of the image to display the image
  String imageUrl = '';

  // This is the name of the teacher initialized in Firebase
  String teacherName = '';

  // This checks whether the user has chosen an image
  bool isPhoto = false;

  // This is the class period (this will be 0 for a club)
  int period = 0;

  // This is the name of the class/club that user has selected
  String schoolClassName = '';

  // This is the name of the student that the teacher is messaging.
  String studentName = '';

  // If the focus on the text field changes, the color of the text field will change as well.
  Color detailFocusColor = Colors.transparent;

  // This will get the name of the student that the teacher is messaging by using the students
  // collection in Firebase.
  Future<void> getStudentName() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('students')
        .doc(widget.studentID)
        .get();

    if (snapshot.exists) {
      setState(() {
        studentName =
            snapshot.data()!['firstName'] + ' ' + snapshot.data()!['lastName'];
      });
    }
  }

  // This function will get the class/club name by using that classes/activities collection in Firebase
  Future<void> getClassName() async {
    var snapshot = await FirebaseFirestore.instance
        .collection(widget.isClass ? 'classes' : 'activities')
        .doc(widget.className)
        .get();

    if (snapshot.exists) {
      setState(() {
        schoolClassName = snapshot.data()!['name'];
        if (widget.isClass) {
          period = snapshot.data()!['period'];
        }
      });
    }
  }

  // This will get all of the messages, the name of the class, and the student that the
  // teacher is messaging when the screen initializes.
  @override
  void initState() {
    loadMessages();
    getClassName();
    getStudentName();
    super.initState();
  }

  // The text field, add icon, and send icon will all be built here.
  Widget buildInputBox() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        child: Material(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 32),
            child: Row(children: [
              LayoutBuilder(builder: (context, constraints) {
                // When the user is not picking an image, the add button will show.
                if (!isPhoto) {
                  return IconButton(
                    icon: Icon(Icons.add),

                    // Permission is asked to access the user's images.
                    onPressed: () {
                      () async {
                        var _permissionStatus = await Permission.storage.status;

                        // Should allow user to grant permission to image gallery
                        if (_permissionStatus != PermissionStatus.granted) {
                          PermissionStatus permissionStatus =
                              await Permission.storage.request();
                          setState(() {
                            _permissionStatus = permissionStatus;
                          });
                        }
                      }();
                      uploadImage();
                    },
                  );
                } else {
                  // When the user is picking an image, the close icon will show, so that the
                  // user can remove the image.
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        isPhoto = false;
                      });
                    },
                    icon: Icon(Icons.close),
                  );
                }
              }),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  if (!isPhoto) {
                    // A text field will show up if the user has not selected an image.
                    return TextFormField(
                      textInputAction: TextInputAction.done,
                      maxLines: null,
                      controller: _textController,
                      style: TextStyle(color: Colors.black),
                      cursorColor: Colors.black,
                      decoration: InputDecoration(
                          hintText: 'Enter message here...',
                          border: InputBorder.none,
                          filled: true,
                          fillColor: detailFocusColor,
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xff78CAD2)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              )),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xff78CAD2)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ))),
                      onChanged: (value) => setState(() {
                        if (!value.isEmpty) {
                          detailFocusColor = Color(0xff78CAD2).withOpacity(0.3);
                        } else {
                          detailFocusColor = Colors.transparent;
                        }
                      }),
                    );
                  } else {
                    // If the user has selected an image, a preview of the image will show in
                    // a container without the text field.
                    return Container(
                      height: MediaQuery.of(context).size.height * 0.1,
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(imageUrl)),
                    );
                  }
                }),
              ),
              IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    // The message or image will send when the send icon is pressed.
                    if (!isPhoto) {
                      String message = _textController.text;
                      print('message: ' + message);
                      sendMessage(message);
                      _textController.clear();
                      loadMessages();
                    } else {
                      print('in photo');
                      // sendImage();
                      setImageData();
                      setState(() {
                        isPhoto = false;
                      });
                    }
                  })
            ]),
          ),
        ),
      ),
    );
  }

  // Widget sendImage() {
  //   return BubbleNormalImage(
  //     id: '',
  //     image: Image.network(imageUrl),
  //     isSender: true,
  //   );
  // }

  Future<void> setImageData() async {
    //store in corressponding document
    CollectionReference imageMessageRef = await db
        .collection("conversations")
        .doc(widget.teacher + widget.studentID + widget.className)
        .collection('messages');

    var data = {
      'className': widget.className,
      'content': imageUrl,
      'isImage': true,
      'announcement': false,
      'reciever': widget.studentID,
      'sender': widget.teacher,
      'timeSent': Timestamp.now()
    };

    imageMessageRef.add(data);
  }

  // This function calls an image picker to choose an image from user gallery
  void uploadImage() async {
    print('in upload image');

    // Pick image from gallery
    ImagePicker picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);

    // Checks if image is null
    if (image == null) {
      print('image is null');
      return;
    }

    // Timestamp for unique name for image
    String uniqueFileName = DateTime.now().millisecondsSinceEpoch.toString();

    // Upload to Firebase storage
    // Get a reference to storage
    Reference referenceRoot = FirebaseStorage.instance.ref();
    Reference referenceDirImages = referenceRoot.child('messageImages');

    // Create reference for image to be stored
    Reference referenceImageToUpload = referenceDirImages.child(uniqueFileName);

    // Handle error/success
    try {
      // Store the file
      await referenceImageToUpload.putFile(File(image.path));

      // Get download URL
      imageUrl = await referenceImageToUpload.getDownloadURL();

      setState(() {
        isPhoto = true;
      });
    } catch (error) {}
  }

  // Widget will load previous messages
  Widget loadMessages() {
    print('in load messages');
    return StreamBuilder(
        stream: db
            .collection('conversations')
            .doc(widget.teacher + widget.studentID + widget.className)
            .collection('messages')
            .orderBy('timeSent')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            print('snapshot has data');
            print('not waiting');
            print(snapshot.data?.size);
            return Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 100),
              child: ListView.builder(
                  controller: _scrollController,
                  itemCount: snapshot.data?.size,
                  itemBuilder: (context, index) {
                    return buildItem(snapshot.data?.docs[index]);
                  }),
            );
          } else {
            return Text("Be the first to send a message");
          }
        });
  }

  // This will build invididual message bubble using the Chat Bubbles package
  Widget buildItem(QueryDocumentSnapshot<Map<String, dynamic>>? document) {
    print('is in build item' + (document?.get('isImage') ? 'image' : 'text'));
    if (document?.get('isImage')) {
      print('is image');
      if (document?.get('sender') == widget.teacher) {
        return BubbleNormalImage(
            color: Colors.transparent,
            id: '',
            isSender: true,
            image: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: ClipRRect(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(0)),
                  child: Image.network(document?.get('content'))),
            ));
      } else {
        return BubbleNormalImage(
            color: Colors.transparent,
            id: "",
            isSender: false,
            image: Padding(
              padding: const EdgeInsets.all(4.0),
              child: ClipRRect(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(0),
                      bottomRight: Radius.circular(20)),
                  child: Image.network(document?.get('content'))),
            ));
      }
    } else {
      print('sending');
      if (document?.get('sender') == widget.teacher) {
        if (document?.get('announcement')) {
          print('sending 2');
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: Text(
                    'ANNOUNCEMENT',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey),
                  ),
                ),
                BubbleNormal(
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                    text: document?.get('content'),
                    color: Color.fromRGBO(120, 202, 210, 1),
                    tail: true,
                    isSender: true),
              ],
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: BubbleNormal(
                textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
                text: document?.get('content'),
                color: Color.fromRGBO(120, 202, 210, 1),
                tail: true,
                isSender: true),
          );
        }
      } else {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: BubbleNormal(
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
              text: document?.get('content'),
              color: Color.fromARGB(255, 251, 145, 198),
              tail: true,
              isSender: false),
        );
      }
    }
  }

  // Handle sending messages including images
  void sendMessage(String content) {
    final data;
    data = {
      'className': widget.className,
      'content': content,
      'isImage': false,
      'announcement': false,
      'reciever': widget.studentID,
      'sender': widget.teacher,
      'timeSent': Timestamp.now()
    };

    final ref = db
        .collection('conversations')
        .doc(widget.teacher + widget.studentID + widget.className)
        .collection('messages')
        .doc();

    if (_textController.text != '') {
      ref.set(data);
      _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300), curve: Curves.easeOut);
    }

    setState(() {
      detailFocusColor = Colors.transparent;
    });

    // return Text(
    //   data['content'],
    //   style: TextStyle(color: Colors.black),
    // );
    // return BubbleNormal(
    //     text: data['content'],
    //     isSender: true,
    //     color: Color.fromRGBO(120, 202, 210, 1),
    //     tail: true);
  }

  // This will display the messages and images in addition to the text field at the bottom.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          toolbarHeight: 100,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          backgroundColor: Color(0xff78CAD2),
          title: Column(
            children: [
              Text(
                widget.isClass
                    ? schoolClassName + ' (P' + period.toString() + ')'
                    : schoolClassName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                studentName,
                style: TextStyle(
                  color: Color(0xffF7F7F7),
                  fontSize: 18,
                ),
              )
            ],
          ),
        ),
        backgroundColor: Colors.white,
        body: Stack(children: <Widget>[
          loadMessages(),
          buildInputBox(),
        ]));
  }
}
