#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Function SelectChanges(Val Node, Val MessageNo) Export
	
	If TransactionActive() Then
		Raise NStr("en='Selection of the data modifications is prohibited in the active transaction.';ru='Выборка изменений данных запрещена в активной транзакции.'");
	EndIf;
	
	Result = New Array;
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.NodesCommonDataChange");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Node", Node);
		Block.Lock();
		
		QueryText =
		"SELECT
		|	NodesCommonDataChange.Node AS Node,
		|	NodesCommonDataChange.MessageNo AS MessageNo
		|FROM
		|	InformationRegister.NodesCommonDataChange AS NodesCommonDataChange
		|WHERE
		|	NodesCommonDataChange.Node = &Node";
		
		Query = New Query;
		Query.SetParameter("Node", Node);
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			Result.Add(Selection.Node);
			
			If Selection.MessageNo = 0 Then
				
				RecordStructure = New Structure;
				RecordStructure.Insert("Node", Node);
				RecordStructure.Insert("MessageNo", MessageNo);
				AddRecord(RecordStructure);
				
			EndIf;
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
EndFunction

Procedure RecordChanges(Val Node) Export
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.NodesCommonDataChange");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Node", Node);
		Block.Lock();
		
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", Node);
		RecordStructure.Insert("MessageNo", 0);
		AddRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteChangeRecords(Val Node, Val MessageNo = Undefined) Export
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.NodesCommonDataChange");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Node", Node);
		Block.Lock();
		
		If MessageNo = Undefined Then
			
			QueryText =
			"SELECT
			|	1 AS Field1
			|FROM
			|	InformationRegister.NodesCommonDataChange AS NodesCommonDataChange
			|WHERE
			|	NodesCommonDataChange.Node = &Node";
			
		Else
			
			QueryText =
			"SELECT
			|	1 AS Field1
			|FROM
			|	InformationRegister.NodesCommonDataChange AS NodesCommonDataChange
			|WHERE
			|	NodesCommonDataChange.Node = &Node
			|	AND NodesCommonDataChange.MessageNo <= &MessageNo
			|	AND NodesCommonDataChange.MessageNo <> 0";
			
		EndIf;
		
		Query = New Query;
		Query.SetParameter("Node", Node);
		Query.SetParameter("MessageNo", MessageNo);
		Query.Text = QueryText;
		
		If Not Query.Execute().IsEmpty() Then
			
			RecordStructure = New Structure;
			RecordStructure.Insert("Node", Node);
			DeleteRecord(RecordStructure);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Procedure adds record in the register by passed structure values.
Procedure AddRecord(RecordStructure)
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "NodesCommonDataChange");
	
EndProcedure

// Procedure deletes a records set in the register by the passed values of the structure.
Procedure DeleteRecord(RecordStructure)
	
	DataExchangeServer.DeleteRecordSetInInformationRegister(RecordStructure, "NodesCommonDataChange");
	
EndProcedure

#EndRegion

#EndIf