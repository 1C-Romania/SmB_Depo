////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Receives text from register storage
//
// Parameters:
//  RecordKey - InformationRegisterRecordKey - the record from which it is necessary to get data.
//
// Returns:
//  String - Text with data
//
Function MessageText(RecordKey) Export
	
	Manager = InformationRegisters.AuditLogbookSberbank.CreateRecordManager();
	FillPropertyValues(Manager, RecordKey);
	Manager.Read();
	Return Manager.MessageText.Get();
	
EndFunction

#EndIf