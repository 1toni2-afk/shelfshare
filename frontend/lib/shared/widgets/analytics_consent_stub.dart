/// Pe ținte non-web nu există bandă de consimțământ, deci nu are ce să se
/// suprapună: răspundem mereu „rezolvat". package:web (dart:js_interop) nu
/// compilează pentru Android/iOS, de aceea împărțirea stub/web.
bool analyticsConsentAnswered() => true;
