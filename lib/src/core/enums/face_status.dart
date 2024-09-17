enum FaceStatus {
  near('Quá gần'),
  far('Quá xa'),
  normal('Vui lòng giữ camera'),
  inProgress('Đang hoàn tất...'),
  unknown('Không xác định'),
  ;

  const FaceStatus(this.text);
  final String text;
}
