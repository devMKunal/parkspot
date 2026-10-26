/// Where a one-shot form submission is: sign up, log in, book, pay.
enum SubmitStatus {
  idle,
  submitting,
  success,
  failure;

  bool get isSubmitting => this == submitting;
}
