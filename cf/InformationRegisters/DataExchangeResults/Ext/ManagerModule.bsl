#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Procedure RegisterErrorChecksObject(Ref, InfobaseNode, Cause, ProblemType) Export
	
	RecordSetConflict = InformationRegisters.DataExchangeResults.CreateRecordSet();
	RecordSetConflict.Filter.ProblematicObject.Set(Ref);
	RecordSetConflict.Filter.ProblemType.Set(ProblemType);
	
	RecordSetConflict.Read();
	RecordSetConflict.Clear();
	
	ConflictRecord = RecordSetConflict.Add();
	ConflictRecord.ProblematicObject = Ref;
	ConflictRecord.ProblemType = ProblemType;
	ConflictRecord.InfobaseNode = InfobaseNode;
	ConflictRecord.AppearanceDate = CurrentSessionDate();
	ConflictRecord.Cause = TrimAll(Cause);
	ConflictRecord.skipped = False;
	ConflictRecord.DeletionMark = CommonUse.ObjectAttributeValue(Ref, "DeletionMark");
	
	If ProblemType = Enums.DataExchangeProblemTypes.UnpostedDocument Then
		
		ConflictRecord.DocumentNumber = CommonUse.ObjectAttributeValue(Ref, "Number");
		ConflictRecord.DocumentDate = CommonUse.ObjectAttributeValue(Ref, "Date");
		
	EndIf;
	
	RecordSetConflict.Write();
	
EndProcedure

Procedure Ignore(Ref, ProblemType, Ignore) Export
	
	RecordSetConflict = InformationRegisters.DataExchangeResults.CreateRecordSet();
	RecordSetConflict.Filter.ProblematicObject.Set(Ref);
	RecordSetConflict.Filter.ProblemType.Set(ProblemType);
	RecordSetConflict.Read();
	RecordSetConflict[0].skipped = Ignore;
	RecordSetConflict.Write();
	
EndProcedure

Function CountProblems(ExchangeNodes = Undefined, ProblemType = Undefined, ConsiderWereIgnored = False, Period = Undefined, SearchString = "") Export
	
	Quantity = 0;
	
	QueryText = "SELECT
	|	COUNT(DataExchangeResults.ProblematicObject) AS CountProblems
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	DataExchangeResults.skipped <> &FilterBySkipped
	|	[FilterByNode]
	|	[FilterByType]
	|	[FilterByPeriod]
	|	[FilterByReason]";
	
	Query = New Query;
	
	FilterBySkipped = ?(ConsiderWereIgnored, Undefined, True);
	Query.SetParameter("FilterBySkipped", FilterBySkipped);
	
	If ProblemType = Undefined Then
		FilterRow = "";
	Else
		FilterRow = "And DataExchangeResults.ProblemType = &ProblemType";
		Query.SetParameter("ProblemType", ProblemType);
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByType]", FilterRow);
	
	If ExchangeNodes = Undefined Then
		FilterRow = "";
	ElsIf ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodes)) Then
		FilterRow = "And DataExchangeResults.IBNode = &IBNode";
		Query.SetParameter("InfobaseNode", ExchangeNodes);
	Else
		FilterRow = "And DataExchangeResults.IBNode IN (&ExchangeNodes)";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	EndIf;
	
	QueryText = StrReplace(QueryText, "[FilterByNode]", FilterRow);
	
	If ValueIsFilled(Period) Then
		
		FilterRow = "And (DataExchangeResults.AppearanceDate >= &StartDate And DataExchangeResults.AppearanceDate <= &EndDate)";
		Query.SetParameter("StartDate", Period.StartDate);
		Query.SetParameter("EndDate", Period.EndDate);
		
	Else
		
		FilterRow = "";
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByPeriod]", FilterRow);
	
	If ValueIsFilled(SearchString) Then
		
		FilterRow = "And DataExchangeResults.Reason LIKE &Reason";
		Query.SetParameter("Cause", "%" + SearchString + "%");
		
	Else
		
		FilterRow = "";
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByReason]", FilterRow);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		Quantity = Selection.CountProblems;
		
	EndIf;
	
	Return Quantity;
	
EndFunction

Procedure RegisterProblemSolving(Source, ProblemType) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	EndIf;
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		SourceRef = Source.Ref;
		
		DeletionMarkNewValue = Source.DeletionMark;
		
		DataExchangeServerCall.RegisterProblemSolving(SourceRef, ProblemType, DeletionMarkNewValue);
		
	EndIf;
	
EndProcedure

Procedure ClearInfobaseNodeReferences(Val InfobaseNode) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeResults.ProblematicObject,
	|	DataExchangeResults.ProblemType,
	|	UNDEFINED AS InfobaseNode,
	|	DataExchangeResults.AppearanceDate,
	|	DataExchangeResults.Cause,
	|	DataExchangeResults.skipped,
	|	DataExchangeResults.DeletionMark,
	|	DataExchangeResults.DocumentNumber,
	|	DataExchangeResults.DocumentDate
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	DataExchangeResults.InfobaseNode = &InfobaseNode";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		RecordSet = InformationRegisters.DataExchangeResults.CreateRecordSet();
		
		RecordSet.Filter["ProblematicObject"].Set(Selection["ProblematicObject"]);
		RecordSet.Filter["ProblemType"].Set(Selection["ProblemType"]);
		
		FillPropertyValues(RecordSet.Add(), Selection);
		
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf