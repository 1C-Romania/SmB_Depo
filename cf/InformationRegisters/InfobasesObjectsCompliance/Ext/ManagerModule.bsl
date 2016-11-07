#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure adds record in the register by passed structure values.
Procedure AddRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "InfobasesObjectsCompliance", Import);
	
EndProcedure

// Procedure deletes a records set in the register by the passed values of the structure.
Procedure DeleteRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.DeleteRecordSetInInformationRegister(RecordStructure, "InfobasesObjectsCompliance", Import);
	
EndProcedure

Function ObjectIsInRegister(Object, InfobaseNode) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.InfobasesObjectsCompliance AS InfobasesObjectsCompliance
	|WHERE
	|	  InfobasesObjectsCompliance.InfobaseNode           = &InfobaseNode
	|	AND InfobasesObjectsCompliance.UniqueSourceHandle = &UniqueSourceHandle
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode",           InfobaseNode);
	Query.SetParameter("UniqueSourceHandle", Object);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Procedure DeleteOutdatedExportModeRecordsByRef(InfobaseNode) Export
	
	QueryText = "
	|////////////////////////////////////////////////////////// {InfobaseObjectMapsByRef}
	|SELECT
	|	InfobasesObjectsCompliance.InfobaseNode,
	|	InfobasesObjectsCompliance.UniqueSourceHandle,
	|	InfobasesObjectsCompliance.UniqueReceiverHandle,
	|	InfobasesObjectsCompliance.ReceiverType,
	|	InfobasesObjectsCompliance.SourceType
	|INTO InfobaseObjectMapsByRef
	|FROM
	|	InformationRegister.InfobasesObjectsCompliance AS InfobasesObjectsCompliance
	|WHERE
	|	  InfobasesObjectsCompliance.InfobaseNode = &InfobaseNode
	|	AND InfobasesObjectsCompliance.ObjectExportedByRef
	|;
	|
	|//////////////////////////////////////////////////////////{}
	|SELECT DISTINCT
	|	InfobaseObjectMapsByRef.InfobaseNode,
	|	InfobaseObjectMapsByRef.UniqueSourceHandle,
	|	InfobaseObjectMapsByRef.UniqueReceiverHandle,
	|	InfobaseObjectMapsByRef.ReceiverType,
	|	InfobaseObjectMapsByRef.SourceType
	|FROM
	|	InfobaseObjectMapsByRef AS InfobaseObjectMapsByRef
	|LEFT JOIN InformationRegister.InfobasesObjectsCompliance AS InfobasesObjectsCompliance
	|ON   InfobasesObjectsCompliance.UniqueSourceHandle = InfobaseObjectMapsByRef.UniqueSourceHandle
	|	AND InfobasesObjectsCompliance.ObjectExportedByRef = FALSE
	|	AND InfobasesObjectsCompliance.InfobaseNode = &InfobaseNode
	|WHERE
	|	Not InfobasesObjectsCompliance.InfobaseNode IS NULL
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			RecordStructure = New Structure("IBNode, UniqueSourceID, UniqueReceiverID, ReceiverType, SourceType");
			
			FillPropertyValues(RecordStructure, Selection);
			
			DeleteRecord(RecordStructure, True);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure AddObjectToFilterOfPermittedObjects(Val Object, Val Recipient) Export
	
	If Not ObjectIsInRegister(Object, Recipient) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Recipient);
		RecordStructure.Insert("UniqueSourceHandle", Object);
		RecordStructure.Insert("ObjectExportedByRef", True);
		
		AddRecord(RecordStructure, True);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf