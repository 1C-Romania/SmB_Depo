////////////////////////////////////COMMON/////////////////////////////////////////////

//Procedure GetObjectModificationFlag(Object) Export

//   Object.AdditionalProperties.Insert("WasModified",Object.Modified());
//   Object.AdditionalProperties.Insert("WasNew",Object.IsNew());
//   Object.AdditionalProperties.Insert("WasPosted",Object.Posted);
//   Object.AdditionalProperties.Insert("DocumentPresentation", String(Object) + "." + Chars.LF);
//   Object.AdditionalProperties.Delete("IsCostError");

//EndProcedure

//Function GetErrorTextNotInStock(Available, Required, UnitOfMeasure, IsFree = False, IsReserved = False) Export 
//	
//	If IsFree Then
//		Return Alerts.ParametrizeString(Nstr("en='Not enough quantity in stock (free, not reserved)! Only %P1 %P2 is available.';pl='Za mała ilość wolnego salda na magazynie! Tylko %P1 %P2 jest dostępne.'"),New Structure("P1, P2",Available,UnitOfMeasure));	
//	ElsIf IsReserved Then
//		Return Alerts.ParametrizeString(Nstr("en='Not enough quantity in stock (reserved for current document)! Only %P1 %P2 is available.';pl='Za mała ilość na magazynie zarezerwowana dla tego dokumentu! Tylko %P1 %P2 jest dostępne.'"),New Structure("P1, P2",Available,UnitOfMeasure));
//	Else	
//		Return Alerts.ParametrizeString(Nstr("en='Not enough quantity in stock! Only %P1 %P2 is available.';pl='Za mała ilość na magazynie! Tylko %P1 %P2 jest dostępne.'"),New Structure("P1, P2",Available,UnitOfMeasure));
//	EndIf;	
//	
//EndFunction // GetErrorTextNotInStock()

//////////////////////////////////////////////////////////////////////////////////

//// Used to get empty value for given type:
////
//// Parameters:
////	Value   - Type, empty value of which should be returned
////
//Function EmptyValueType(Val Value) Export 

//	If Value = Type("Number") Then
//		Return 0;

//	ElsIf Value = Type("String") Then
//		Return "";

//	ElsIf Value = Type("Date") Then
//		Return '00010101000000';

//	ElsIf Value = Type("Boolean") Then
//		Return False;

//	Else
//		Return New (Value);

//	EndIf;

//EndFunction // TypeEmptyValue();

Function ValueIsNotFilled(Val Value) Export
	
	Try
		Return Not ValueIsFilled(Value);
	Except
		// mutable type
		Return False
	EndTry;
	
EndFunction // ValueIsNotFilled()

Function ABS(Number) Export 
	
	If Number<0 Then
		Return -Number;
	Else
		Return Number;
	EndIf;
	
EndFunction

Function RoundNumber(Number, RoundingPrecision = 0.01, RoundingType = Undefined) Export 
	
	If RoundingPrecision = 0 Then
		Return 0;
	EndIf;
	
	If RoundingType = Undefined Then
		RoundingType = PredefinedValue("Enum.NumberRoundingTypes.Normal");
	EndIf;
	
	IntervalsNumber = Number/RoundingPrecision;
	IntegerIntervalsNumber = Int(IntervalsNumber);
		
	If IntervalsNumber = IntegerIntervalsNumber Then
		
		Return Number;
		
	Else
		
		If RoundingType = PredefinedValue("Enum.NumberRoundingTypes.Up") Then
			
			// If round precision = "0.05" then 0.374 should became 0.4
			Return RoundingPrecision*(IntegerIntervalsNumber + 1);
			
		
		ElsIf RoundingType = PredefinedValue("Enum.NumberRoundingTypes.Down") Then
			
			// If round precision = "0.05" then 0.374 should became 0.35
			Return RoundingPrecision*(IntegerIntervalsNumber);
			
		Else
			
			// If round precision = "0.05" then 0.374 should became 0.35 and 0.375 should became 0.4
			Return RoundingPrecision*Round(IntervalsNumber, 0 , RoundMode.Round15as20);
			
		EndIf;
		
	EndIf;
	
EndFunction // RoundNumber()

//Function GetValuePresentation(Val Value) Export
//	
//	If ValueIsFilled(Value) Then
//		Return String(Value);
//	Else
//		Return Nstr("en='<Not defined>';pl='<Nie zdefiniowana>'");
//	EndIf;
//	
//EndFunction

//// Function checks the given String for presence of significant characters
////
//// Parameters:
//// SelString – String to be checked
//// IndicationComma - indicates whether to append the resulting String with comma
////
//// Returns:
//// String - Space or empty String value
////
//Function StringFunctionsClientServer.AddStringSeparator(Val InitialString, Val Separator = ",") Export 
//	
//	If IsBlankString(InitialString) Then
//		Return "";
//	Else
//		Return Separator + " ";
//	EndIf; 
//	
//EndFunction

//// Output error message on client or on server in the message window.
//// In case of external Connection Raise is called.
////
//// Parameters:
////  MessageText - String, message text.
////  Cancel      - boolean, cancellation flag.
////  Title       - String, message title, will output before message.
////  Status      - MessageStatus, message status, Important by default.
////
//Procedure ErrorMessage(Val MessageText, Cancel = Undefined, Title = "", Val Status = Undefined, Val ObjectRef = Undefined) Export 
//	
//	If Status = Undefined Then
//		Status = MessageStatus.Important;
//	EndIf;
//	
//	MessageTextBegin    = Find(MessageText, "{");
//	MessageTextEnd = Find(MessageText, "}:");
//	If MessageTextEnd > 0 And MessageTextBegin > 0 Then
//		MessageText = Left(MessageText, (MessageTextBegin - 1)) + Mid(MessageText, (MessageTextEnd + 2));
//	EndIf;
//	
//	Cancel = True;
//	
//	#If ExternalConnection Then
//		
//		If Not IsBlankString(Title) Then
//			MessageText = Title + Chars.LF + MessageText;
//			Title = "";
//		EndIf;
//		
//		Raise(MessageText);
//		
//	#Else
//		
//		#If Server Then
//			
//			If Status = MessageStatus.Important 
//				OR Status = MessageStatus.VeryImportant Then
//				
//				LogEventStatus = EventLogLevel.Error;
//				
//			ElsIf Status = MessageStatus.Attention Then
//				
//				LogEventStatus = EventLogLevel.Warning;
//				
//			ElsIf Status = MessageStatus.Information Then	
//				
//				LogEventStatus = EventLogLevel.Information;
//				
//			Else	
//				
//				LogEventStatus = EventLogLevel.Note;
//				
//			EndIf;	
//			
//			WriteLogEvent("ServerErrorMessages",LogEventStatus, ?(ObjectRef = Undefined,ObjectRef,ObjectRef.Metadata()), ObjectRef ,?(Title<>"",Title + Chars.CR + Chars.LF,"") + MessageText,?(TransactionActive(),EventLogEntryTransactionMode.Transactional,EventLogEntryTransactionMode.Independent));
//			
//		#EndIf	
//		
//		If Not IsBlankString(Title) Then
//			Message(Title);
//			Title = "";
//		EndIf;
//		
//		Message(MessageText, Status);
//		
//	#EndIf
//	
//EndProcedure // ErrorMessage()

//////////////////////////////////////////////////////////////////////////////////
//// PROCEDURES AND FUNCTIONS WORKING WITH NUMBERS 

//Function ABS(Val Number) Export 
//	
//	If Number<0 Then
//		Return -Number;
//	Else
//		Return Number;
//	EndIf;
//	
//EndFunction

//Function RoundNumber(Val Number, Val RoundingPrecision = 0.01, Val RoundingType = Undefined) Export 
//	
//	If RoundingPrecision = 0 Then
//		Return 0;
//	EndIf;
//	
//	If RoundingType = Undefined Then
//		RoundingType = PredefinedValue("Enum.NumberRoundingTypes.Normal");
//	EndIf;
//	
//	IntervalsNumber = Number/RoundingPrecision;
//	IntegerIntervalsNumber = Int(IntervalsNumber);
//		
//	If IntervalsNumber = IntegerIntervalsNumber Then
//		
//		Return Number;
//		
//	Else
//		
//		If RoundingType = PredefinedValue("Enum.NumberRoundingTypes.Up") Then
//			
//			// If round precision = "0.05" then 0.374 should became 0.4
//			Return RoundingPrecision*(IntegerIntervalsNumber + 1);
//			
//		
//		ElsIf RoundingType = PredefinedValue("Enum.NumberRoundingTypes.Down") Then
//			
//			// If round precision = "0.05" then 0.374 should became 0.35
//			Return RoundingPrecision*(IntegerIntervalsNumber);
//			
//		Else
//			
//			// If round precision = "0.05" then 0.374 should became 0.35 and 0.375 should became 0.4
//			Return RoundingPrecision*Round(IntervalsNumber, 0 , RoundMode.Round15as20);
//			
//		EndIf;
//		
//	EndIf;
//	
//EndFunction // RoundNumber()

//// Reduces String value (almost number value) to number value, if possible
//// E.g. " 100 szt." -> "100", "1.54zł." -> "1,54"
//// Works by trimming blank spaces and non-numeric characters from both sides
//Function GetNumberReducedFromString(Val StringNumber) Export 

//	// Remove all blank spaces and replace dots with commas
//	StringNumber = StrReplace(StrReplace(StringNumber, " ", ""), ".", ",");
//		
//	While True Do
//		
//		If StringNumber = "" Then 
//			Break;
//		EndIf;
//		
//		// Check if the most right character of the String is numeric
//		Try                                                                        			
//			Digit = Number(Right(StringNumber, 1));
//			// If the most right character of the String is numeric, then quit loop
//			Break;                                                                 			
//		Except
//			StringNumber = Left(StringNumber, StrLen(StringNumber)-1);
//		EndTry;
//		
//	EndDo;
//	
//	While True Do
//		
//		If StringNumber = "" Then 
//			Break;
//		EndIf;
//		
//		// Check if the most left character of the String is numeric
//		Try                                                                        			
//			Digit = Number(Left(StringNumber, 1));
//			// If the most left character of the String is numeric, then quit loop
//			Break;                                                                 			
//		Except
//			StringNumber = Right(StringNumber, StrLen(StringNumber)-1);
//		EndTry;
//		
//	EndDo;
//	
//	Return StringNumber;		
//	
//EndFunction

//////////////////////////////////////////////////////////////////////////////////
//// PROCEDURES AND FUNCTIONS WORKING WITH ERRORS

//Function GetLongDescription(Val Object) Export 
//	
//	If IsBlankString(Object.LongDescription) Then
//		Return Object.Description;
//	Else
//		Return Object.LongDescription;
//	EndIf;
//	
//EndFunction // GetLongDescription()

//Function FormatAmount(Val Amount, Currency = Undefined, NZ = "", NGS = "",PrintCurrencyDescription = True) Export 
//	
//	CurrencyFormat = "ND=15; NFD=2;";
//	FormatString = CurrencyFormat + " NZ=" + NZ + ?(IsBlankString(NGS),"", ";" + "NGS=" + NGS);
//	ResultString = Format(Amount, FormatString);
//	If PrintCurrencyDescription AND Not IsBlankString(ResultString) Then
//		ResultString = ResultString + ?(Currency = Undefined, "", " " + Currency);
//	EndIf;	
//	
//	Return ResultString;
//	
//EndFunction // FormatAmount()

//Function AmountInWords(Val Amount, Val Currency, Val LanguageCode = Undefined) Export
//	
//	If LanguageCode = Undefined Then
//		FormatString = "L="+GetDefaultLanguageCodeAndDescription().LanguageCode+";";
//		NumerationItemOptions = Currency.FormatStringPl;
//	Else
//		FormatString = "L=" + LanguageCode + ";";
//		If upper(LanguageCode) = upper("ru") Then
//			NumerationItemOptions = Currency.FormatStringRu;
//		ElsIf upper(LanguageCode) = upper("en") Then	
//			NumerationItemOptions = Currency.FormatStringEn;
//		ElsIf upper(LanguageCode) = upper("pl") Then	
//			NumerationItemOptions = Currency.FormatStringPl;	
//		Else
//			NumerationItemOptions = "";
//		EndIf;
//	EndIf;
//	
//	Return NumberInWords(Amount, FormatString, NumerationItemOptions);
//	
//EndFunction

//Procedure UnderConstruction() Export
//	
//#If Client Then
//	DoMessageBox(NStr("en='This option is temporary under construction.';pl='Ta opcja jest tymczasowo w fazie budowy.'"));
//#Else
//	Message(NStr("en='This option is temporary under construction.';pl='Ta opcja jest tymczasowo w fazie budowy.'"));
//#EndIf
//	
//EndProcedure // UnderConstruction()

//Function GetDefaultLanguageCodeAndDescription() Export
//	
//	Return New Structure("LanguageCode, Description","pl", NStr("en = 'Polish'; pl = 'Polski'; ru = 'Польский'"));
//	
//EndFunction

//////////////////////////////////////////////////////////////////////////////////
//////// Free days counter

//Function DaySeconds() Export
//	Return 86400;
//EndFunction

//Function GetEasterStructure()
//	
//	EasterStructure = New Structure();
//	EasterStructure.Insert("y2008",'2008.03.23');
//	EasterStructure.Insert("y2009",'2009.04.12');
//	EasterStructure.Insert("y2010",'2010.04.04');
//	EasterStructure.Insert("y2011",'2011.04.24');
//	EasterStructure.Insert("y2012",'2012.04.08');
//	EasterStructure.Insert("y2013",'2013.03.31');
//	EasterStructure.Insert("y2014",'2014.04.20');
//	EasterStructure.Insert("y2015",'2015.04.05');
//	EasterStructure.Insert("y2016",'2016.03.27');
//	EasterStructure.Insert("y2017",'2017.04.16');
//	
//	return EasterStructure;
//	
//EndFunction

//Function IsFreeDay(Val Date,SaturdayIsFree = False) Export
//	
//	Date = BegOfDay(Date);
//	// niedziele
//	If WeekDay(Date) = 7 Then
//		Return True;	
//	EndIf;
//	
//	If SaturdayIsFree AND WeekDay(Date) = 6 Then
//		Return True;
//	EndIf;	
//	
//	Year = Year(Date);
//	Month = Month(Date);
//	Day = Day(Date);
//	
//	// święta nieruchome
//	If (Month = 1 AND Day = 1) // Nowy Rok
//		OR (Month = 1 AND Day = 6 AND Year>2011) // Trzech Króli
//		OR (Month = 5 AND Day = 1) // Pierwsze maja
//		OR (Month = 5 AND Day = 3) // Święto trzeciego maja
//		OR (Month = 8 AND Day = 15) // Wniebowzięcie Najświętszej Maryi Panny
//		OR (Month = 11 AND Day = 1) // Wszystkich Świętych
//		OR (Month = 11 AND Day = 11) // Narodowe Święto Niepodległości
//		OR (Month = 12 AND Day = 25) // pierwszy dzień Bożego Narodzenia
//		OR (Month = 12 AND Day = 26) // drugi dzień Bożego Narodzenia
//		Then
//		Return True;
//	EndIf;	
//	
//	// święta ruchome
//	// Wielkanoc	
//	EasterStructure = GetEasterStructure();
//	FoundEasterDay = EasterStructure["y"+Format(Year,"NG=0")];
//	If Date = FoundEasterDay // Pierwszy dzień Wielkiej Nocy
//		Or Date = FoundEasterDay+DaySeconds()  // Drugi dzień Wielkiej Nocy
//		Or Date = FoundEasterDay+49*DaySeconds() // Pierwszy dzień Zielonych Świątek
//		Or Date = FoundEasterDay+60*DaySeconds() // Dzień Bożego Ciała
//		Then
//		Return True;
//	EndIf;	
//	
//	Return False;
//	
//EndFunction

///////////////////////////////////////////////////////////////////////////////////////////////////
///// Working with strings

//// Get tokens from string
//// Tokens can be separated by , and ;
//Function TokenizeString(val String) Export
//	
//	Tokens = New Array();
//	EndOfString = StrLen(String)+1;
//	i = 1;
//	While i<>EndOfString Do
//		
//		Token = "";
//		CurChar = "";
//		While i<>EndOfString Do
//			CurChar = Mid(String,i,1);
//			If IsBlankString(CurChar) Then
//				// space
//				i = i+1;
//			Else
//				Break;
//			EndIf;	
//		EndDo;	
//		
//		If i = EndOfString Then
//			Break;
//		EndIf;	
//		
//		If CurChar = """" OR CurChar = "\" Then
//			// read lexem between separators
//			Quotation = CurChar;
//			i = i+1;
//			While i<>EndOfString Do
//				CurChar = Mid(String,i,1);
//				If CurChar = Quotation Then
//					i = i+1;
//					If (i=EndOfString OR Mid(String,i,1) = Quotation) Then
//						Break;
//					EndIf;	
//				EndIf;
//				Token = Token + Mid(String,i,1);
//				i = i+1;
//			EndDo;
//			
//			// skip spaces till separator
//			If i<>EndOfString Then
//				
//				While True Do
//					
//					i = i+1;
//					CurChar = Mid(String,i,1);
//					
//					If i<>EndOfString OR NOT IsBlankString(CurChar) Then
//						Break;
//					EndIf;	
//					
//				EndDo;	
//				
//			EndIf;	
//			
//		Else
//			// read lexem before separator
//			While i<>EndOfString Do
//				
//				CurChar = Mid(String,i,1);
//				If CurChar = "," OR CurChar = ";" Then
//					break;
//				EndIf;
//				Token = Token + CurChar;
//				i = i+1;
//				
//			EndDo;
//			Token = TrimR(Token);
//		EndIf;	
//		Tokens.Add(Token);
//		If i<>EndOfString Then
//			i= i+1;
//		EndIf;	
//	EndDo;	
//	
//	Return Tokens;
//	
//EndFunction	

//////////////////////////////////////////////////////////////////////////////////
//// PROCEDURES AND FUNCTIONS WORKING WITH CURRENCIES 

//Function GetPaymentDate(InitialDate, PaymentTerm) Export 
//	
//	If InitialDate = '00010101' Then
//		Return InitialDate;
//	EndIf;
//	
//	PaymentDate = BegOfDay(InitialDate);
//	
//	If TypeOf(PaymentTerm) <> Type("FormDataStructure") And PaymentTerm.IsEmpty() Then
//		Return PaymentDate;
//	EndIf;
//	
//	If PaymentTerm.PaymentDay = PredefinedValue("Enum.PaymentDays.InvoiceDate") Then
//		
//		// Nothing to do.
//		
//	ElsIf PaymentTerm.PaymentDay = PredefinedValue("Enum.PaymentDays.EndOfWeek") Then
//		
//		PaymentDate = EndOfWeek(PaymentDate);
//		
//	ElsIf PaymentTerm.PaymentDay = PredefinedValue("Enum.PaymentDays.EndOfMonth") Then
//		
//		PaymentDate = EndOfMonth(PaymentDate);
//		
//	ElsIf PaymentTerm.PaymentDay = PredefinedValue("Enum.PaymentDays.EndOfQuarter") Then
//		
//		PaymentDate = EndOfQuarter(PaymentDate);
//		
//	ElsIf PaymentTerm.PaymentDay = PredefinedValue("Enum.PaymentDays.EndOfYear") Then
//		
//		PaymentDate = EndOfYear(PaymentDate);
//		
//	EndIf;
//	
//	MonthToAdd = PaymentTerm.Months*PaymentTerm.MonthsSign; 
//	PaymentDate = AddMonth(PaymentDate, MonthToAdd);
//	If (PaymentTerm.PaymentDay = PredefinedValue("Enum.PaymentDays.EndOfMonth")
//		OR PaymentTerm.PaymentDay = PredefinedValue("Enum.PaymentDays.EndOfQuarter"))
//		AND MonthToAdd<>0 Then
//		PaymentDate = EndOfMonth(PaymentDate);
//	EndIf;	
//	PaymentDate = BegOfDay(PaymentDate) + PaymentTerm.Days*PaymentTerm.DaysSign*60*60*24;
//	
//	Return PaymentDate;
//	
//EndFunction // GetPaymentDay()

//Function GetDocumentRemarks(DocumentObject, BusinessPartner = Undefined) Export
//	Return ObjectsExtensionsAtServer.GetDocumentRemarksStructure(DocumentObject, BusinessPartner).Remarks;
//EndFunction	

//Procedure FillRemarks(DocumentObject, BusinessPartner = Undefined,Overwrite = False) Export
//	
//	RemarksStructure = ObjectsExtensionsAtServer.GetDocumentRemarksStructure(DocumentObject, BusinessPartner);
//	
//	If IsBlankString(DocumentObject.Remarks) OR Overwrite Then
//		DocumentObject.Remarks = RemarksStructure.Remarks;
//	EndIf;
//	
//	If IsBlankString(DocumentObject.AdditionalInformation) OR Overwrite Then
//		DocumentObject.AdditionalInformation = RemarksStructure.AdditionalInformation;
//	EndIf;
//	
//EndProcedure

Function GetValuePresentation(Val Value) Export
	
	If ValueIsFilled(Value) Then
		Return String(Value);
	Else
		Return Nstr("en='<Not defined>';pl='<Nie zdefiniowana>'");
	EndIf;
	
EndFunction

// Used to get empty value for given type:
//
// Parameters:
//	Value   - Type, empty value of which should be returned
//
Function EmptyValueType(Val Value) Export 

	If Value = Type("Number") Then
		Return 0;

	ElsIf Value = Type("String") Then
		Return "";

	ElsIf Value = Type("Date") Then
		Return '00010101000000';

	ElsIf Value = Type("Boolean") Then
		Return False;

	Else
		Return New (Value);

	EndIf;

EndFunction // UniversalReports.TypeEmptyValue();

Function FormatAmount(Val Amount, Val Currency = Undefined, Val NZ = "", Val NGS = "",Val PrintCurrencyDescription = True) Export 
	
	CurrencyFormat = "ND=15; NFD=2;";
	FormatString = CurrencyFormat + " NZ=" + NZ + ?(IsBlankString(NGS),"", ";" + "NGS=" + NGS);
	ResultString = Format(Amount, FormatString);
	If PrintCurrencyDescription AND Not IsBlankString(ResultString) Then
		ResultString = ResultString + ?(Currency = Undefined, "", " " + Currency);
	EndIf;	
	
	Return ResultString;
	
EndFunction // FormatAmount()




