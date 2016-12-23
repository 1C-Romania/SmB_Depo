
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













