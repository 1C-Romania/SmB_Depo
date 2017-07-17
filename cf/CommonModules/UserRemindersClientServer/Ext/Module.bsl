////////////////////////////////////////////////////////////////////////////////
// Subsystem "User reminders".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns an array of text representations of standard time intervals.
Function GetStandardAlertsIntervals() Export
	
	Result = New Array;
	
	IntervalsTime = New Structure("_5m,_10m,_15m,_30m,_1h,_2h,_4h,_8h,_1d,_2d,_3d,_1w,_2w");
	For Each Interval IN IntervalsTime Do
    	Result.Add(MakeTime(Interval.Key));
	EndDo;
	
	UserRemindersClientServerOverridable.WhenReceivingStandardNotificationsIntervals(Result);
	
	Return Result;
	
EndFunction

// Returns the text presentation of the time interval specified in seconds.
//
// Parameters:
//
//  Time - Number - time interval in seconds.
//
//  FullPresentation	- Boolean - short or full time presentation.
// 	For example, 1,000,000 seconds interval:
// 	- full presentation: 11 days 13 hours 46 minutes 40 seconds;
// 	- short presentation: 11 days 13 hours
//
// Returns:
//   String - time interval presentation.
//
Function TimePresentation(Val Time, FullPresentation = True, OutputSeconds = True) Export
	Result = "";
	
	// Presentation of the time measurement units in the accusative case for quantities: 1, 2-4, 5-20.
	WeeksRepresentation	= NStr("en='Week';ru='Неделя'")  + "," + NStr("en='weeks';ru='недели'")  + "," + NStr("en='weeks';ru='недель'");
	DaysRepresentation	= NStr("en='day';ru='дне'")    + "," + NStr("en='days';ru='дня'")     + "," + NStr("en='days';ru='дня'");
	HoursRepresentation	= NStr("en='hour';ru='час'")     + "," + NStr("en='hours';ru='часа'")    + "," + NStr("en='Hours';ru='часы'");
	MinutesRepresentation	= NStr("en='minute';ru='минуту'")  + "," + NStr("en='minutes';ru='минуты'")  + "," + NStr("en='minutes';ru='минут'");
	SecondsRepresentation	= NStr("en='second';ru='секунду'") + "," + NStr("en='Seconds';ru='секунды'") + "," + NStr("en='Seconds';ru='секунды'");
	
	Time = Number(Time);
	
	If Time < 0 Then
		Time = -Time;
	EndIf;
	
	WeeksNumber = Int(Time / 60/60/24/7);
	DaysNumber   = Int(Time / 60/60/24);
	HoursCount  = Int(Time / 60/60);
	MinutesCount  = Int(Time / 60);
	CountSeconds = Int(Time);
	
	CountSeconds = CountSeconds - MinutesCount * 60;
	MinutesCount  = MinutesCount - HoursCount * 60;
	HoursCount  = HoursCount - DaysNumber * 24;
	DaysNumber   = DaysNumber - WeeksNumber * 7;
	
	If Not OutputSeconds Then
		CountSeconds = 0;
	EndIf;
	
	If WeeksNumber > 0 AND DaysNumber+HoursCount+MinutesCount+CountSeconds=0 Then
		Result = StringFunctionsClientServer.NumberInDigitsMeasurementUnitInWords(WeeksNumber, WeeksRepresentation);
	Else
		DaysNumber = DaysNumber + WeeksNumber * 7;
		
		Counter = 0;
		If DaysNumber > 0 Then
			Result = Result + StringFunctionsClientServer.NumberInDigitsMeasurementUnitInWords(DaysNumber, DaysRepresentation) + " ";
			Counter = Counter + 1;
		EndIf;
		
		If HoursCount > 0 Then
			Result = Result + StringFunctionsClientServer.NumberInDigitsMeasurementUnitInWords(HoursCount, HoursRepresentation) + " ";
			Counter = Counter + 1;
		EndIf;
		
		If (FullPresentation Or Counter < 2) AND MinutesCount > 0 Then
			Result = Result + StringFunctionsClientServer.NumberInDigitsMeasurementUnitInWords(MinutesCount, MinutesRepresentation) + " ";
			Counter = Counter + 1;
		EndIf;
		
		If (FullPresentation Or Counter < 2) AND (CountSeconds > 0 Or WeeksNumber+DaysNumber+HoursCount+MinutesCount = 0) Then
			Result = Result + StringFunctionsClientServer.NumberInDigitsMeasurementUnitInWords(CountSeconds, SecondsRepresentation);
		EndIf;
		
	EndIf;
			  
	Return TrimR(Result);
	
EndFunction

// Receives the time interval in seconds from the text description.
//
// Parameters:
//  StringWithTime - String - text description of time where the
// 							numbers are written in digits and measurement units as a - String. 
//
// Return
//  value Number - time interval in seconds.
Function GetTimeIntervalFromString(Val StringWithTime) Export
	
	Result = 0;
	If Not IsBlankString(StringWithTime) Then
		StringWithTime = Lower(StringWithTime);
		
		StringWithTime = StrReplace(StringWithTime, Chars.NBSp," ");
		StringWithTime = StrReplace(StringWithTime, ".",",");
		StringWithTime = StrReplace(StringWithTime, "+","");
		
		SubstringWithNumbers = "";
		SubstringWithLetters = "";
		StringForCalculation = "0";
		
		PreviousSymbolIsDigit = False;
		IsFractionalPart = False;
		IsMeasurementUnit = False;
		
		For Position = 1 To StrLen(StringWithTime) Do
			CurrentSymbolCode = CharCode(StringWithTime,Position);
			Char = Mid(StringWithTime,Position,1);
			If (CurrentSymbolCode >= CharCode("0") AND CurrentSymbolCode <= CharCode("9"))
				OR (Char="," AND PreviousSymbolIsDigit AND Not IsFractionalPart) Then
				If Not IsBlankString(SubstringWithLetters) Then
					StringForCalculation = StringForCalculation 
										+ "+"
										+ ?(IsBlankString(SubstringWithNumbers),"1",SubstringWithNumbers)
										+ "*"
										+ ReplaceUnitDimensionsOnFactor(SubstringWithLetters);
					SubstringWithNumbers = "";
					SubstringWithLetters = "";
					
					PreviousSymbolIsDigit = False;
					IsFractionalPart = False;
					IsMeasurementUnit = False;
				EndIf;
				
				SubstringWithNumbers = SubstringWithNumbers + Mid(StringWithTime,Position,1);
				
				PreviousSymbolIsDigit = True;
				If Char = "," Then
					IsFractionalPart = True;
				EndIf;
			Else
				If Char = " " AND ReplaceUnitDimensionsOnFactor(SubstringWithLetters)="0" Then
					SubstringWithLetters = "";
				EndIf;
				
				SubstringWithLetters = SubstringWithLetters + Mid(StringWithTime,Position,1);
				PreviousSymbolIsDigit = False;
			EndIf;
		EndDo;
		
		If Not IsBlankString(SubstringWithLetters) Then
				StringForCalculation = StringForCalculation 
									+ "+"
									+ ?(IsBlankString(SubstringWithNumbers),"1",SubstringWithNumbers)
									+ "*"
									+ ReplaceUnitDimensionsOnFactor(SubstringWithLetters);
		EndIf;

		StringForCalculation = StrReplace(StringForCalculation,",",".");
		Result = Eval(StringForCalculation);
	EndIf;
	
	Return Result;
	
EndFunction

// Analyzes the word for compliance to the time
// unit, and if it is compliant, it returns the number of seconds contained in the time unit.
//
// Parameters:
//  Unit - String - the analized word.
//
// Return
//  value Number - number of seconds in the Unit. If the unit is not defined or empty, then 0 is returned.
Function ReplaceUnitDimensionsOnFactor(Val Unit)
	
	Result = 0;
	
	Unit = StrReplace(Unit, " ","");
	Unit = StrReplace(Unit, ",","");
	Unit = StrReplace(Unit, ".","");
	
	// Time measurement unit will be determined by the first three characters.
	FirstThreeSymbols = Left(Unit,3);
	If FirstThreeSymbols = NStr("en='week';ru='неделю'") Or FirstThreeSymbols = NStr("en='n';ru='н'") Then
		Result = 60*60*24*7;
	ElsIf FirstThreeSymbols = NStr("en='day';ru='дне'") 
		  Or FirstThreeSymbols = NStr("en='day';ru='дне'")
		  Or FirstThreeSymbols = NStr("en='days';ru='дня'")
		  Or FirstThreeSymbols = NStr("en='days';ru='дня'")
		  Or FirstThreeSymbols = NStr("en='days';ru='дн'") Then
		Result = 60*60*24;
	ElsIf FirstThreeSymbols = NStr("en='hour';ru='час'") Or FirstThreeSymbols = NStr("en='h';ru='ch'") Then
		Result = 60*60;
	ElsIf FirstThreeSymbols = NStr("en='min';ru='мин'") Or FirstThreeSymbols = NStr("en='m';ru='m'") Then
		Result = 60;
	ElsIf FirstThreeSymbols = NStr("en='sec';ru='сек'") Or FirstThreeSymbols = NStr("en='From';ru='Списать из'") Then
		Result = 1;
	EndIf;
	
	Return Format(Result,"NZ=0; NG=0");
	
EndFunction

// Receives time interval from the string and returns its text presentation.
//
// Parameters:
//  TimeAsString - String - text description of time where the
// 						numbers are written in digits and measurement units as a - String.
//
// Return
//  value String - completed time presentation.
Function MakeTime(TimeAsString) Export
	Return TimePresentation(GetTimeIntervalFromString(TimeAsString));
EndFunction

// Returns the reminder structure with filled values.
//
// Parameters:
//  DataForFilling - Structure - values for filling the reminder parameters.
//  AllAttributes - Boolean - if true, then it also returns the attributes
//                          associated with the setting of reminder time.
Function GetReminderStructure(DataForFilling = Undefined, AllAttributes = False) Export
	Result = New Structure("User,EventTime,Source,ReminderPeriod,Definition");
	If AllAttributes Then 
		Result.Insert("ReminderTimeSettingVariant");
		Result.Insert("ReminderInterval");
		Result.Insert("SourceAttributeName");
		Result.Insert("Schedule");
		Result.Insert("PictureIndex", 2);
	EndIf;
	If DataForFilling <> Undefined Then
		FillPropertyValues(Result, DataForFilling);
	EndIf;
	Return Result;
EndFunction

#EndRegion
