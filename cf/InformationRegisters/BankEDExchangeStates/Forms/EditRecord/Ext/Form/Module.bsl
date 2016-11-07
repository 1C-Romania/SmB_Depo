////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("EDAgreement") Then
		CurrentRecord = InformationRegisters.BankEDExchangeStates.CreateRecordManager();
		CurrentRecord.EDFSetup = Parameters.EDAgreement;
		CurrentRecord.Read();
		
		// There are still no records in register for new ED agreement
		If Not CurrentRecord.Selected() Then
			CurrentRecord.EDFSetup = Parameters.EDAgreement;
		EndIf;
	
		ValueToFormAttribute(CurrentRecord, "Record");
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
