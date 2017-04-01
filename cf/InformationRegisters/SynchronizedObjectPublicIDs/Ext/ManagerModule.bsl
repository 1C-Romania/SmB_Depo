#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure adds record in the register by passed structure values.
Procedure AddRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "SynchronizedObjectPublicIDs", Import);
	
EndProcedure

Function NoteHasInRegister(RecordStructure) Export
	
	RecordSet = InformationRegisters.SynchronizedObjectPublicIDs.CreateRecordSet();
	
	// Set filter by register changes.
	For Each Item IN RecordStructure Do
		RecordSet.Filter[Item.Key].Set(Item.Value);
	EndDo;

	RecordSet.Read();
	
	Return RecordSet.Count() > 0;
	
EndFunction

// Procedure deletes a records set in the register by the passed values of the structure.
Procedure DeleteRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.DeleteRecordSetInInformationRegister(RecordStructure, "SynchronizedObjectPublicIDs", Import);
	
EndProcedure

// Converts a reference to object of the current infobase to the UI row presentation.
// If there is such reference in the SynchronizedObjectsPublicIDs register, then UI is returned from the register.
// Otherwise, UI of the passed row is returned.
// 
// Parameters:
//  InfobaseNode - Ref to an exchange plan node to which the data is exported.
//  ObjectReference - ref to the infobase object for which
//                   you need to receive a unique identifier of the XDTO object.
//
// Returns:
//  String - Object unique identifier.
Function PublicIdentifierByObjectRef(InfobaseNode, ObjectReference) Export
	SetPrivilegedMode(True);
	
	// Define a public reference through a reference to an object.
	Query = New Query("
		|SELECT
		|	ID 
		|FROM InformationRegister.SynchronizedObjectPublicIDs
		|WHERE InfobaseNode = &InfobaseNode AND
		|	Refs = &Refs");
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("Ref", ObjectReference);
	Selection = Query.Execute().Select();
	If Selection.Count() = 1 Then
		Selection.Next();
		Return TrimAll(Selection.ID);
	ElsIf Selection.Count() > 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Several unique identifiers are assigned for <%1> reference and <%2> node.';ru='Для ссылки <%1> и узла <%2> назначено несколько уникальных идентификаторов.'"),
				String(ObjectReference), String(InfobaseNode)
				);
	EndIf;
	// Receive UI of the current row.
	Return TrimAll(ObjectReference.UUID());

EndFunction

#EndRegion

#EndIf