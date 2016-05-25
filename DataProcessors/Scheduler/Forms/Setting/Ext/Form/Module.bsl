
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure fills form attributes from parameters.
//
&AtServer
Procedure FillAttributesByParameters()
	
	If Parameters.Property("TimeLimitFrom") Then
		TimeLimitFrom = Parameters.TimeLimitFrom;
		TimeLimitFromOnOpen = Parameters.TimeLimitFrom;
	EndIf;
	
	If Parameters.Property("TimeLimitTo") Then
		TimeLimitTo = Parameters.TimeLimitTo;
		TimeLimitToOnOpen = Parameters.TimeLimitTo;
	EndIf;
	
	If Parameters.Property("RepetitionFactorOFDay") Then
		RepetitionFactorOFDay = Parameters.RepetitionFactorOFDay;
		RepetitionFactorOFDayOnOpen = Parameters.RepetitionFactorOFDay;
	EndIf;
	
	If Parameters.Property("ShowJobOrders") Then
		If Parameters.ShowJobOrders Then
			ShowDocuments = "JobOrders";
			ShowDocumentsOnOpen = "JobOrders";
		EndIf
	EndIf;
	
	If Parameters.Property("ShowProductionOrders") Then
		If Parameters.ShowProductionOrders Then
			If IsBlankString(ShowDocuments) Then
				ShowDocuments = "ProductionOrders";
				ShowDocumentsOnOpen = "ProductionOrders";
			Else
				ShowDocuments =  "AllDocuments";
				ShowDocumentsOnOpen = "AllDocuments";
			EndIf;
		EndIf;
	EndIf;
	
	If Parameters.Property("WorkSchedules") Then
		If Parameters.WorkSchedules Then
			Items.ShowedDocuments.ChoiceList.Delete(1);
		Else
			Items.ShowedDocuments.ChoiceList.Delete(0);
		EndIf;
	EndIf;
	
EndProcedure // CheckIfFormWasModified()

// Procedure checks if the form was modified.
//
&AtClient
Procedure CheckIfFormWasModified()
	
	WereMadeChanges = False;
	
	ChangesShowDocuments = ?(ShowDocumentsOnOpen <> ShowDocuments, False, True);
	ChangesTimeLimitFrom = ?(TimeLimitFromOnOpen <> TimeLimitFrom, False, True);
	ChangesTimeLimitTo = ?(TimeLimitToOnOpen <> TimeLimitTo, False, True);
	ChangesRepetitionFactorOFDay = ?(RepetitionFactorOFDayOnOpen <> RepetitionFactorOFDay, False, True);
	
	If ChangesShowDocuments
	 OR ChangesTimeLimitFrom
	 OR ChangesTimeLimitTo
	 OR ChangesRepetitionFactorOFDay Then
		WereMadeChanges = True;
	EndIf;
	
EndProcedure // CheckIfFormWasModified()

&AtClient
// The procedure allows to receive a list for the time selection divided by hours
//
Function GetListSelectTime(DateForChoice)

	WorkingDayBeginning      = '00010101000000';
	WorkingDayEnd   = '00010101235959';

	TimeList = New ValueList;
	WorkingDayBeginning = BegOfHour(BegOfDay(DateForChoice) +
		Hour(WorkingDayBeginning) * 3600 +
		Minute(WorkingDayBeginning)*60);
	WorkingDayEnd = EndOfHour(BegOfDay(DateForChoice) +
		Hour(WorkingDayEnd) * 3600 +
		Minute(WorkingDayEnd)*60);

	ListTime = WorkingDayBeginning;
	While BegOfHour(ListTime) <= BegOfHour(WorkingDayEnd) Do
		If Not ValueIsFilled(ListTime) Then
			TimePresentation = "00:00";
		Else
			TimePresentation = Format(ListTime,"DF=HH:mm");
		EndIf;

		TimeList.Add(ListTime, TimePresentation);

		ListTime = ListTime + 3600;
	EndDo;

	Return TimeList;

EndFunction // GetTimeChoiceList()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillAttributesByParameters();
	
	WereMadeChanges = False;
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure OnOpen(Cancel)
	
	SmallBusinessClientServer.FillListByList(GetListSelectTime(TimeLimitFrom),Items.TimeLimitFrom.ChoiceList);
	SmallBusinessClientServer.FillListByList(GetListSelectTime(TimeLimitTo),Items.TimeLimitTo.ChoiceList);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - event handler of clicking the OK button.
//
&AtClient
Procedure CommandOK(Command)
	
	CheckIfFormWasModified();
	
	StructureOfFormAttributes = New Structure;
	
	StructureOfFormAttributes.Insert("WereMadeChanges", WereMadeChanges);
	
	StructureOfFormAttributes.Insert("ShowJobOrders", ShowDocuments = "JobOrders");
	StructureOfFormAttributes.Insert("ShowProductionOrders", ShowDocuments = "ProductionOrders");
	
	If ShowDocuments = "AllDocuments" Then
		StructureOfFormAttributes.Insert("ShowJobOrders", True);
		StructureOfFormAttributes.Insert("ShowProductionOrders", True);
	EndIf;
	
	StructureOfFormAttributes.Insert("TimeLimitFrom", TimeLimitFrom);
	StructureOfFormAttributes.Insert("TimeLimitTo", TimeLimitTo);
	
	StructureOfFormAttributes.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	
	Close(StructureOfFormAttributes);
	
EndProcedure // CommandOK()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - OnChange event handler of the TimeLimitationFrom attribute.
//
&AtClient
Procedure TimeLimitFromOnChange(Item)
	
	If TimeLimitTo <= TimeLimitFrom 
		AND TimeLimitTo <> '00010101000000'
		AND TimeLimitFrom <> '00010101000000' Then
		TimeLimitTo = TimeLimitFrom + 1800;
		Return;
	EndIf;
	
EndProcedure // TimeLimitFromOnChange()

// Procedure - OnChange event handler of the TimeLimitationTo attribute.
//
&AtClient
Procedure TimeLimitToOnChange(Item)
	
	If TimeLimitTo <= TimeLimitFrom 
		AND TimeLimitTo <> '00010101000000'
		AND TimeLimitFrom <> '00010101000000' Then
		Message(NStr("en='Ending time can not be less or equal to beginning time.'"));
		TimeLimitTo = TimeLimitFrom + 1800;
		Return;
	EndIf;
	
EndProcedure // TimeLimitToOnChange()



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
