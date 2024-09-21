// ignore_for_file: library_private_types_in_public_api

class StringConstants {
  static _LabelStrings label = _LabelStrings();
  static _ButtonStrings button = _ButtonStrings();
}

class _LabelStrings {
  final String livelyNessDetection = "Xác thực khuôn mặt";
  final String goodLighting = "Đủ ánh sáng";
  final String lookStraight = "Nhìn thẳng";
  final String clearFace = "Rõ mặt";
  final String goodLightingSubText =
      "Đảm bảo môi trường xung quanh có đủ ánh sáng tự nhiên hoặc đèn chiếu sáng để camera có thể thu nhận khuôn mặt một cách rõ nét. Tránh chụp trong bóng tối hoặc ánh sáng quá mạnh làm lóa hình ảnh";
  final String lookStraightSubText =
      "Để đảm bảo nhận diện chính xác, hãy giữ đầu thẳng và nhìn trực tiếp vào camera";
  final String clearFaceSubText =
      "Khuôn mặt cần được hiển thị rõ ràng, không che khuất bởi kính râm, khẩu trang, tóc hay bất kỳ vật dụng nào khác. Tránh có nhiều khuôn mặt trong lúc xác thực";
  final String infoSubText =
      "Để thực hiện xác thực khuôn mặt trên điện thoại, vui lòng tuân thủ các yêu cầu sau";
}

class _ButtonStrings {
  final String start = "Bắt đầu";
}
