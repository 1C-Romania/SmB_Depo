﻿
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("EDFProfileSettings") Then
		CurrentRecord = InformationRegisters.EDExchangeStatesThroughEDFOperators.CreateRecordManager();
		CurrentRecord.EDFProfileSettings = Parameters.EDFProfileSettings;
		
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	EDExchangeStatesThroughEDFOperators.EDDateReceived,
		|	EDExchangeStatesThroughEDFOperators.LastInvitationsDateReceived
		|FROM
		|	InformationRegister.EDExchangeStatesThroughEDFOperators AS EDExchangeStatesThroughEDFOperators
		|WHERE
		|	EDExchangeStatesThroughEDFOperators.EDFProfileSettings = &EDFProfileSettings";
		Query.SetParameter("EDFProfileSettings", Parameters.EDFProfileSettings);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			CurrentRecord.EDDateReceived = Selection.EDDateReceived;
			CurrentRecord.LastInvitationsDateReceived = Selection.LastInvitationsDateReceived;
		EndIf;
		ThisObject.ValueToFormAttribute(CurrentRecord, "Record");
		
	EndIf;
	
EndProcedure


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
