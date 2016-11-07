#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Procedure AddObjectToFilterOfPermittedObjects(Val Object, Val Recipient) Export
	
	If Not ObjectIsInRegister(Object, Recipient) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Recipient);
		RecordStructure.Insert("Ref", Object);
		
		AddRecord(RecordStructure, True);
	EndIf;
	
EndProcedure


Function ObjectIsInRegister(Object, InfobaseNode) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.ObjectDataForRegistrationInExchanges AS ObjectDataForRegistrationInExchanges
	|WHERE
	|	  ObjectDataForRegistrationInExchanges.InfobaseNode           = &InfobaseNode
	|	AND ObjectDataForRegistrationInExchanges.Ref = &Object
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("Object", Object);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

// Procedure adds record in the register by transferred structure values.
Procedure AddRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "ObjectDataForRegistrationInExchanges", Import);
	
EndProcedure

#EndRegion

#EndIf