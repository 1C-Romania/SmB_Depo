#Region FormHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisObject, Parameters, "BeginOfPeriod,EndOfPeriod");
	BegOfYearDate = ?(ValueIsFilled(EndOfPeriod), BegOfYear(EndOfPeriod), BegOfYear(CurrentSessionDate()));
	
	// init monthes names
	For MonthNumber = 1 to 12 Do
		
		Items["SelectMonth"+MonthNumber].Title = Format(Date(1,MonthNumber,10),"DF=MMMM");
		
	EndDo;	
	
	// Find active period name
	If BegOfDay(BeginOfPeriod) = BegOfDay(EndOfPeriod) Then
		CurrentItemName = "SelectDay";
	ElsIf BegOfMonth(BeginOfPeriod) = BegOfMonth(EndOfPeriod) Then
		BegOfMonth = Month(BeginOfPeriod);
		CurrentItemName = "SelectMonth" + BegOfMonth;
	ElsIf BegOfQuarter(BeginOfPeriod) = BegOfQuarter(EndOfPeriod) Then
		BegOfMonth = Month(BeginOfPeriod);
		QuarterNumber = Int((BegOfMonth + 3) / 3);
		CurrentItemName = "SelectQuarter" + QuarterNumber;
	ElsIf BegOfYear(BeginOfPeriod) = BegOfYear(EndOfPeriod) Then
		BegOfStartMonth = Month(BeginOfPeriod);
		BegOfEndMonth  = Month(EndOfPeriod);
		If BegOfStartMonth <= 3 AND BegOfEndMonth <= 6 Then
			CurrentItemName = "SelectHalfYear";
		ElsIf BegOfStartMonth <= 3 AND BegOfEndMonth <= 9 Then
			CurrentItemName = "Select9Monthes";
		Else
			CurrentItemName = "SelectYear";
		EndIf;
	Else
		CurrentItemName = "SelectYear";
	EndIf;
	
	CurrentItem = Items[CurrentItemName];
	
	CurrentItem.BackColor = WebColors.Gold;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GoToPrevoiusYear(Command)
	
	BegOfYearDate = BegOfYear(BegOfYearDate - 1);
	
	CurrentItem = Items[CurrentItemName];
	
EndProcedure

&AtClient
Procedure GoToNextYear(Command)
	
	BegOfYearDate = EndOfYear(BegOfYearDate) + 1;
	
	CurrentItem = Items[CurrentItemName];
	
EndProcedure

&AtClient
Procedure SelectMonth1(Command)
	
	SelectMonth(1);
	
EndProcedure

&AtClient
Procedure SelectMonth2(Command)
	
	SelectMonth(2);
	
EndProcedure

&AtClient
Procedure SelectMonth3(Command)
	
	SelectMonth(3);
	
EndProcedure

&AtClient
Procedure SelectMonth4(Command)
	
	SelectMonth(4);
	
EndProcedure

&AtClient
Procedure SelectMonth5(Command)
	
	SelectMonth(5);
	
EndProcedure

&AtClient
Procedure SelectMonth6(Command)
	
	SelectMonth(6);
	
EndProcedure

&AtClient
Procedure SelectMonth7(Command)
	
	SelectMonth(7);
	
EndProcedure

&AtClient
Procedure SelectMonth8(Command)
	
	SelectMonth(8);
	
EndProcedure

&AtClient
Procedure SelectMonth9(Command)
	
	SelectMonth(9);
	
EndProcedure

&AtClient
Procedure SelectMonth10(Command)
	
	SelectMonth(10);
	
EndProcedure

&AtClient
Procedure SelectMonth11(Command)
	
	SelectMonth(11);
	
EndProcedure

&AtClient
Procedure SelectMonth12(Command)
	
	SelectMonth(12);
	
EndProcedure

&AtClient
Procedure SelectQuarter1(Command)
	
	SelectQuarter(1);
	
EndProcedure

&AtClient
Procedure SelectQuarter2(Command)
	
	SelectQuarter(2);
	
EndProcedure

&AtClient
Procedure SelectQuarter3(Command)
	
	SelectQuarter(3);
	
EndProcedure

&AtClient
Procedure SelectQuarter4(Command)
	
	SelectQuarter(4);
	
EndProcedure

&AtClient
Procedure SelectDay(Command)
	
	DayLimitBegin = BeginOfPeriod;
	If DayLimitBegin = '00010101' Then
		DayLimitBegin = BegOfYearDate;
	EndIf;	
	
	DayLimitEnd = EndOfPeriod;
	If DayLimitEnd = '00010101' Then
		DayLimitEnd = EndOfYear(BegOfYearDate);
	EndIf;	
	
	FormParameters = New Structure("BeginOfPeriod, EndOfPeriod", DayLimitBegin, DayLimitEnd);
	
	NotifyDescription = New NotifyDescription("SelectDayFinish", ThisObject);
	OpenForm(
		"CommonForm.StandardPeriodDayChoiceForm", 
		FormParameters, 
		ThisObject,
		,
		,
		,
		NotifyDescription);
	
EndProcedure

&AtClient
Procedure SelectHalfYear(Command)
	
	BeginOfPeriod = BegOfYearDate;
	EndOfPeriod  = EndOfMonth(AddMonth(BeginOfPeriod, 5));
	PerformPeriodSelect();
	
EndProcedure

&AtClient
Procedure Select9Monthes(Command)

	BeginOfPeriod = BegOfYearDate;
	EndOfPeriod  = Date(Year(BegOfYearDate), 9 , 30);
	PerformPeriodSelect();
	
EndProcedure

&AtClient
Procedure SelectYear(Command)

	BeginOfPeriod = BegOfYearDate;
	EndOfPeriod  = EndOfYear(BegOfYearDate);
	PerformPeriodSelect();
	
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure PerformPeriodSelect()

	ChoiceResult = New Structure("BeginOfPeriod,EndOfPeriod", BeginOfPeriod, EndOfDay(EndOfPeriod));
	Close(ChoiceResult);
	
EndProcedure 

&AtClient
Procedure SelectMonth(BegOfMonth)
	
	BeginOfPeriod = Date(Year(BegOfYearDate), BegOfMonth, 1);
	EndOfPeriod  = EndOfMonth(BeginOfPeriod);
	
	PerformPeriodSelect();
	
EndProcedure

&AtClient
Procedure SelectQuarter(QuarterNumber)
	
	BeginOfPeriod = Date(Year(BegOfYearDate), 1 + (QuarterNumber - 1) * 3, 1);
	
	EndOfPeriod  = EndOfQuarter(BeginOfPeriod);
	
	PerformPeriodSelect();
	
EndProcedure

&AtClient
Procedure SelectDayFinish(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		BeginOfPeriod = Result.BeginOfPeriod;
		EndOfPeriod  = Result.EndOfPeriod;
		PerformPeriodSelect();
	EndIf;
	
EndProcedure

#EndRegion
