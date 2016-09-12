﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	FindHistory = FindHistory();
	If TypeOf(FindHistory) = Type("Array") Then
		Items.SearchString.ChoiceList.LoadValues(FindHistory);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RunSearch(Command)
	
	AttachIdleHandler("OpenSearchForm", 0.1, True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenSearchForm()
	
	If IsBlankString(SearchString) Then
		ShowMessageBox(, NStr("en='Enter search string.';ru='Введите, что нужно найти.'"));
		Return;
	EndIf;
	
	ParametersForm = New Structure;
	ParametersForm.Insert("TransferredSearchString", SearchString);
	
	FormName = StrReplace(FormName, ".SimplifiedForm", ".Form");
	OpenForm(FormName, ParametersForm, , True);
	
	FindHistory = FindHistory();
	If TypeOf(FindHistory) = Type("Array") Then
		Items.SearchString.ChoiceList.LoadValues(FindHistory);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FindHistory()
	Return CommonUse.CommonSettingsStorageImport("FulltextSearchFulltextSearchStrings");
EndFunction

#EndRegion



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
