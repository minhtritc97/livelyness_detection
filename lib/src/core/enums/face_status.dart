enum FaceStatus {
  near('Vui lòng di chuyển camera ra xa'),
  far('Vui lòng di chuyển camera lại gần'),
  inProgress('Đang xử lý...'),
  unknown(''),
  up(''),
  down(''),
  right(''),
  left('');

  const FaceStatus(this.text);
  final String text;
}
