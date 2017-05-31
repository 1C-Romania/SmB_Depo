///////////////////////////////////////////////////////////////////////////////////////////////////
// WARNING! this module does not supports TempTablesManager and Batch queries as the items of batch queries
// all parameters with same names in queries will be replaced.


// Creates batch query structure
// Key - name of query
// Value - Query object
Function CreateBatchQuery() Export

	Return New Structure();

EndFunction	

// Adds query to batch query
Procedure AddQuery(BatchQueryStructure,NewQueryName,NewQuery) Export
	
	BatchQueryStructure.Insert(NewQueryName,NewQuery);
	
EndProcedure	

Procedure DeleteQuery(BatchQueryStructure,NewQueryName) Export
	
	BatchQueryStructure.Delete(NewQueryName);
	
EndProcedure	

Function GetQuery(BatchQueryStructure,NewQueryName) Export
	
	Return BatchQueryStructure.NewQueryName;
	
EndFunction

Procedure SetQuery(BatchQueryStructure,NewQueryName,NewQuery) Export
	
	If BatchQueryStructure.Property(NewQueryName) Then
		BatchQueryStructure.Insert(NewQueryName,NewQuery);
	EndIf;	
	
EndProcedure	

Function GenerateQueryFromBatchQuery(BatchQueryStructure, Parameters = Undefined) Export
	
	Query = New Query;
	For Each KeyAndValue In BatchQueryStructure Do
		
		Query.Text = Query.Text + KeyAndValue.Value.Text + ";";
		For Each ParameterKeyAndValue In KeyAndValue.Value.Parameters Do
			Query.SetParameter(ParameterKeyAndValue.Key, ParameterKeyAndValue.Value);
		EndDo;	
		
	EndDo;	
	
	If Parameters <> Undefined Then
		For Each KeyAndValue In Parameters Do
			Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;	
	EndIf;	
	
	Return Query;
	
EndFunction

Function ExecuteBatchQuery(BatchQueryStructure, Parameters = Undefined) Export
	
	Query = New Query;
	IndexStructure = New Structure;
	IndexCounter = 0;
	For Each KeyAndValue In BatchQueryStructure Do
		
		Query.Text = Query.Text + KeyAndValue.Value.Text + ";";
		For Each ParameterKeyAndValue In KeyAndValue.Value.Parameters Do
			Query.SetParameter(ParameterKeyAndValue.Key, ParameterKeyAndValue.Value);
		EndDo;	
		
		IndexStructure.Insert(KeyAndValue.Key,IndexCounter);
		
		IndexCounter = IndexCounter + 1;
		
	EndDo;	
	
	If Parameters <> Undefined Then
		For Each KeyAndValue In Parameters Do
			Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;	
	EndIf;	
	
	QueryResultArray = Query.ExecuteBatch();
	ResultStructure = New Structure();
	For Each KeyAndValue In IndexStructure Do
		
		ResultStructure.Insert(KeyAndValue.Key,QueryResultArray[KeyAndValue.Value]);
		
	EndDo;	

	Return ResultStructure;
	
EndFunction


