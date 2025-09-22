 /// 앱 전역 통화 코드(표시/변환/설정 공통)
 const supportedCurrencies = <String>[
   'KRW','USD','EUR','JPY','NZD','AUD','CAD','GBP','CNY','HKD','SGD',
 ];
 /// (별칭) 기존 코드가 kSupportedCurrencies를 참조한다면 유지
 const kSupportedCurrencies = supportedCurrencies;

 /// '$' 기호 기본 해석 후보(설정에서 선택)
 const kDollarDefaultOptions = <String>['USD','AUD','NZD','CAD'];
