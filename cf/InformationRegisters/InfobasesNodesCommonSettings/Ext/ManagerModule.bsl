#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Work with this information register is allowed only through record manager.
// IN this way the existing records update mode is provided.
// Add records in this register by
// record sets is forbidden, as. the settings which are not included in the records set will be lost.

#Region ServiceProceduresAndFunctions

Procedure SetInitialDataExportFlag(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", InfobaseNode);
	RecordStructure.Insert("InitialDataExport", True);
	RecordStructure.Insert("NumberOfSentStartingDataExport",
		CommonUse.ObjectAttributeValue(InfobaseNode, "SentNo") + 1);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure ClearInitialDataExportFlag(Val InfobaseNode, Val ReceivedNo) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.InfobaseNodeCommonSettings");
		LockItem.SetValue("InfobaseNode", InfobaseNode);
		Block.Lock();
		
		QueryText = "
		|SELECT 1
		|FROM
		|	InformationRegister.InfobasesNodesCommonSettings AS InfobasesNodesCommonSettings
		|WHERE
		|	InfobasesNodesCommonSettings.InfobaseNode = &InfobaseNode
		|	AND InfobasesNodesCommonSettings.InitialDataExport
		|	AND InfobasesNodesCommonSettings.NumberOfSentStartingDataExport <= &ReceivedNo
		|	AND InfobasesNodesCommonSettings.NumberOfSentStartingDataExport <> 0
		|";
		
		Query = New Query;
		Query.SetParameter("InfobaseNode", InfobaseNode);
		Query.SetParameter("ReceivedNo", ReceivedNo);
		Query.Text = QueryText;
		
		If Not Query.Execute().IsEmpty() Then
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", InfobaseNode);
			RecordStructure.Insert("InitialDataExport", False);
			RecordStructure.Insert("NumberOfSentStartingDataExport", 0);
			
			UpdateRecord(RecordStructure);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function InitialDataExportFlagIsSet(Val InfobaseNode) Export
	
	QueryText =
	"SELECT
	|	1 AS Field1
	|FROM
	|	InformationRegister.InfobasesNodesCommonSettings AS InfobasesNodesCommonSettings
	|WHERE
	|	InfobasesNodesCommonSettings.InfobaseNode = &InfobaseNode
	|	AND InfobasesNodesCommonSettings.InitialDataExport";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

//

Procedure CommitCorrectionExecutionOfInformationMatchingUnconditionally(InfobaseNode) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", InfobaseNode);
	RecordStructure.Insert("ExecuteInformationComparingCorrection", False);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure CommitCorrectionExecutionOfInformationMatching(InfobaseNode, SentNo) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.InfobasesNodesCommonSettings AS InfobasesNodesCommonSettings
	|WHERE
	|	InfobasesNodesCommonSettings.InfobaseNode = &InfobaseNode
	|	AND InfobasesNodesCommonSettings.ExecuteInformationComparingCorrection
	|	AND InfobasesNodesCommonSettings.SentNo <= &SentNo
	|	AND InfobasesNodesCommonSettings.SentNo <> 0
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("SentNo", SentNo);
	Query.Text = QueryText;
	
	If Not Query.Execute().IsEmpty() Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", InfobaseNode);
		RecordStructure.Insert("ExecuteInformationComparingCorrection", False);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Procedure SetNecessityOfExecutionOfMappingInformationCorrectionForAllInfobaseNodes() Export
	
	ExchangePlanList = DataExchangeReUse.SLExchangePlanList();
	
	For Each Item IN ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		If Metadata.ExchangePlans[ExchangePlanName].DistributedInfobase Then
			Continue;
		EndIf;
		
		NodesArray = DataExchangeReUse.GetExchangePlanNodesArray(ExchangePlanName);
		
		For Each Node IN NodesArray Do
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", Node);
			RecordStructure.Insert("ExecuteInformationComparingCorrection", True);
			
			UpdateRecord(RecordStructure);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function NeedToExecuteCorrectionOfMappingInformation(InfobaseNode, SentNo) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.InfobasesNodesCommonSettings AS InfobasesNodesCommonSettings
	|WHERE
	|	  InfobasesNodesCommonSettings.InfobaseNode = &InfobaseNode
	|	AND InfobasesNodesCommonSettings.ExecuteInformationComparingCorrection
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Result = Not Query.Execute().IsEmpty();
	
	If Result Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", InfobaseNode);
		RecordStructure.Insert("ExecuteInformationComparingCorrection", True);
		RecordStructure.Insert("SentNo", SentNo);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
	Return Result;
EndFunction

Function UserForDataSynchronization(Val InfobaseNode) Export
	
	QueryText =
	"SELECT
	|	InfobasesNodesCommonSettings.UserForDataSynchronization AS UserForDataSynchronization
	|FROM
	|	InformationRegister.InfobasesNodesCommonSettings AS InfobasesNodesCommonSettings
	|WHERE
	|	InfobasesNodesCommonSettings.InfobaseNode = &InfobaseNode";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		
		Selection.Next();
		
		Return ?(ValueIsFilled(Selection.UserForDataSynchronization), Selection.UserForDataSynchronization, Undefined);
		
	EndIf;
	
	Return Undefined;
EndFunction

//

Procedure SetDataSendSign(Val Recipient) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", Recipient);
	RecordStructure.Insert("PerformDataSending", True);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure RemoveSignOfDataTransfer(Val Recipient) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	If PerformDataSending(Recipient) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Recipient);
		RecordStructure.Insert("PerformDataSending", False);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Function PerformDataSending(Val Recipient) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return False;
	EndIf;
	
	QueryText =
	"SELECT
	|	InfobasesNodesCommonSettings.PerformDataSending AS PerformDataSending
	|FROM
	|	InformationRegister.InfobasesNodesCommonSettings AS InfobasesNodesCommonSettings
	|WHERE
	|	InfobasesNodesCommonSettings.InfobaseNode = &Recipient";
	
	Query = New Query;
	Query.SetParameter("Recipient", Recipient);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.PerformDataSending = True;
EndFunction

//

Procedure SetVersionOfCorrespondent(Val Correspondent, Val Version) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	If IsBlankString(Version) Then
		Version = "0.0.0.0";
	EndIf;
	
	If CorrespondentVersion(Correspondent) <> TrimAll(Version) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Correspondent);
		RecordStructure.Insert("CorrespondentVersion", TrimAll(Version));
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Function CorrespondentVersion(Val Correspondent) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return "0.0.0.0";
	EndIf;
	
	QueryText =
	"SELECT
	|	InfobasesNodesCommonSettings.CorrespondentVersion AS CorrespondentVersion
	|FROM
	|	InformationRegister.InfobasesNodesCommonSettings AS InfobasesNodesCommonSettings
	|WHERE
	|	InfobasesNodesCommonSettings.InfobaseNode = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return "0.0.0.0";
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Result = TrimAll(Selection.CorrespondentVersion);
	
	If IsBlankString(Result) Then
		Result = "0.0.0.0";
	EndIf;
	
	Return Result;
EndFunction

//

// Procedure updates record in the register by the passed structure values.
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateRecordToInformationRegister(RecordStructure, "InfobasesNodesCommonSettings");
	
EndProcedure

#EndRegion

#EndIf
