////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Cursor queries for independent sets of records

Function GetDataPortionIndependentRecordSet(Val ObjectMetadata, Val Filter,
		Val PortionSize, CanContinue, Status, Val AdditionToTableName = "") Export
	
	If Status = Undefined Then
		Status = InitializeStateForIndependentRecordSetPortionsSelection(ObjectMetadata, Filter, AdditionToTableName);
		CanContinue = True;
	EndIf;
	
	Result = New Array;
	
	LeftToReceive = PortionSize; // Left to receive in this portion
	
	FirstSelection = False;
	
	CurrentQuery = 0; // Index of the current query
	
	While True Do // Get fragments of portions
		PortionFragment = Undefined; // Last received portion fragment
		
		If Not Status.WasSelection Then // The first query
			Status.WasSelection = True;
			FirstSelection = True;
			
			Query = New Query;
			Query.Text = StrReplace(Status.Queries.First, "[PortionSize]", Format(LeftToReceive, "NG="));
		Else
			Query = New Query;
			If Status.Queries.Successive.Count() <> 0 Then 
				QueryDescription = Status.Queries.Successive[CurrentQuery];
				CurrentQuery = CurrentQuery + 1;
				Query.Text = StrReplace(QueryDescription.Text, "[PortionSize]", Format(LeftToReceive, "NG="));
				If QueryDescription.ConditionFields <> Undefined Then 
					For Each ConditionField IN QueryDescription.ConditionFields Do
						Query.SetParameter(ConditionField, Status.Key[ConditionField]);
					EndDo;
				EndIf;
			EndIf;
		EndIf;
		
		For Each FilterParameter IN Status.Queries.Parameters Do
			Query.SetParameter(FilterParameter.Key, FilterParameter.Value);
		EndDo;
		
		If Not IsBlankString(Query.Text) Then 
			PortionFragment = Query.Execute().Unload();
			
			FragmentSize = PortionFragment.Count();
		Else
			FragmentSize = 0;
		EndIf;
		
		If FragmentSize > 0 Then
			Result.Add(PortionFragment);
			
			FillPropertyValues(Status.Key, PortionFragment[FragmentSize - 1]);
		EndIf;
		
		If FragmentSize < LeftToReceive Then
			
			If Not FirstSelection // If it was the first query - there is no point in continuing
				AND CurrentQuery < Status.Queries.Successive.Count() Then
				
				LeftToReceive = LeftToReceive - FragmentSize;
				
				Continue; // Transfer to the next query
			Else
				CanContinue = False;
			EndIf;
		EndIf;
		
		Break;
		
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Cursor queries for independent sets of records

Function InitializeStateForIndependentRecordSetPortionsSelection(Val ObjectMetadata, Val Filter, Val AdditionToTableName = "")
	
	ThisIsInformationRegister    = Metadata.InformationRegisters.Contains(ObjectMetadata);
	
	ThisSequence = Metadata.Sequences.Contains(ObjectMetadata);
	
	KeyFields = New Array; // Fields forming the record key
	
	If ThisIsInformationRegister AND ObjectMetadata.InformationRegisterPeriodicity 
		<> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		
		KeyFields.Add("Period");
	EndIf;
	
	If ThisSequence Then 
		
		KeyFields.Add("Recorder");
		KeyFields.Add("Period");
		
	EndIf;
	
	AddSeparatorsToKey(ObjectMetadata, KeyFields);
	
	For Each MetadataMeasurements IN ObjectMetadata.Dimensions Do
		KeyFields.Add(MetadataMeasurements.Name);
	EndDo;
	
	SelectionFields = New Array; // All fields
	
	If ThisIsInformationRegister Then 
		
		For Each MetadataResource IN ObjectMetadata.Resources Do
			SelectionFields.Add(MetadataResource.Name);
		EndDo;
		
		For Each AttributeMetadata IN ObjectMetadata.Attributes Do
			SelectionFields.Add(AttributeMetadata.Name);
		EndDo;
		
	EndIf;
	
	For Each KeyField IN KeyFields Do
		SelectionFields.Add(KeyField);
	EndDo;
	
	TableAlias = "_RecordSetTable"; // Alias of the table in the text of the query
	
	SelectionFieldsRow = ""; // Part of the query text with selection fields
	For Each SelectionField IN SelectionFields Do
		If Not IsBlankString(SelectionFieldsRow) Then
			SelectionFieldsRow = SelectionFieldsRow + "," + Chars.LF;
		EndIf;
		
		SelectionFieldsRow = SelectionFieldsRow + Chars.Tab + TableAlias + "." + SelectionField + " AS " + SelectionField;
	EndDo;
	
	OrderingFieldsRow = ""; //Part of the query text with arranging fields
	For Each KeyField IN KeyFields Do
		If Not IsBlankString(OrderingFieldsRow) Then
			OrderingFieldsRow = OrderingFieldsRow + ", ";
		EndIf;
		OrderingFieldsRow = OrderingFieldsRow + KeyField;
	EndDo;
	
	If TypeOf(Filter) = Type("Array") Then
		Filter = GenerateSelectionCondition(TableAlias, Filter);
	EndIf;
	
	// Prepare queries for receiving portions
	If KeyFields.Count() = 0 Then 
		QueryPattern = // Common part of query
		"SELECT
		|" + SelectionFieldsRow + "
		|IN
		|	" + ObjectMetadata.FullName() + AdditionToTableName + " AS " + TableAlias + "
		|[Condition]";
	Else
		QueryPattern = // Common part of query
		"SELECT TOP [PortionSize]
		|" + SelectionFieldsRow + "
		|IN
		|	" + ObjectMetadata.FullName() + AdditionToTableName + " AS " + TableAlias + "
		|[Condition]
		|ORDER BY
		|	" + OrderingFieldsRow;
	EndIf;
	
	// Query for receiving the first portion
	If Not IsBlankString(Filter.FilterCondition) Then
		FirstPortionReceivingQueryText = StrReplace(QueryPattern, 
			"[Condition]", 
			"WHERE
			|	" + Filter.FilterCondition);
	Else
		FirstPortionReceivingQueryText = StrReplace(QueryPattern, "[Condition]", ""); // Query for receiving the first portion
	EndIf;
	
	Queries = New Array; // Queries for receiving successive portions
	For QueriesCounter = 0 To KeyFields.UBound() Do
		
		ConditionFieldsRow = ""; // Part of the query text with condition fields
		ConditionFields = New Array; // Fields taking part in the condition
		
		ConditionsFieldsQuantity = KeyFields.Count() - QueriesCounter;
		For FieldIndex = 0 To ConditionsFieldsQuantity - 1 Do
			If Not IsBlankString(ConditionFieldsRow) Then
				ConditionFieldsRow = ConditionFieldsRow + " AND ";
			EndIf;
			
			KeyField = KeyFields[FieldIndex];
			
			If FieldIndex = ConditionsFieldsQuantity - 1 Then
				LogicalOperator = ">";
			Else
				LogicalOperator = "=";
			EndIf;
			
			ConditionFieldsRow = ConditionFieldsRow + TableAlias + "." + KeyField + " " 
				+ LogicalOperator + " &" + KeyField;
				
			ConditionFields.Add(KeyField);
		EndDo;
		
		If Not IsBlankString(Filter.FilterCondition) Then
			ConditionFieldsRow = Filter.FilterCondition + " AND " + ConditionFieldsRow;
		EndIf;
		
		QueryDescription = New Structure("Text, ConditionFields");
		QueryDescription.Text = StrReplace(QueryPattern, "[Condition]", 
			"WHERE
			|	" + ConditionFieldsRow);
		QueryDescription.ConditionFields = New FixedArray(ConditionFields);
		
		Queries.Add(New FixedStructure(QueryDescription));
		
	EndDo;
	
	QueriesDescriptions = New Structure;
	QueriesDescriptions.Insert("First", FirstPortionReceivingQueryText);
	QueriesDescriptions.Insert("Successive", New FixedArray(Queries));
	QueriesDescriptions.Insert("Parameters", Filter.FilterParameters);
	
	KeyStructure = New Structure; // Structure for storing the value of the last key
	For Each KeyField IN KeyFields Do
		KeyStructure.Insert(KeyField);
	EndDo;
	
	Status = New Structure;
	Status.Insert("Queries", New FixedStructure(QueriesDescriptions));
	Status.Insert("Key", KeyStructure);
	Status.Insert("WasSelection", False);
	
	Return Status;
	
EndFunction

Procedure AddSeparatorsToKey(ObjectMetadata, KeyFields)
	
	For Each CommonAttribute IN Metadata.CommonAttributes Do 

		If Not CommonAttribute.UseSharedData = Metadata.ObjectProperties.UseSharedDataCommonAttribute.IndependentlyAndJointly Then 
			Continue;
		EndIf;
		
		CommonAttributeItem = CommonAttribute.Content.Find(ObjectMetadata);
		If CommonAttributeItem <> Undefined Then
			
			If ItemUsedInSeparator(CommonAttribute, CommonAttributeItem) Then  
				KeyFields.Add(CommonAttribute.Name);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ItemUsedInSeparator(CommonAttribute, CommonAttributeItem)
	
	CommonAttributeAutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse;
	CommonAttributeUse     = Metadata.ObjectProperties.CommonAttributeUse;
	
	If CommonAttribute.AutoUse = CommonAttributeAutoUse.Use Then 
		If CommonAttributeItem.Use = CommonAttributeUse.Auto
			Or CommonAttributeItem.Use = CommonAttributeUse.Use Then 
				Return True;
		Else
				Return False;
		EndIf;
	Else
		If CommonAttributeItem.Use = CommonAttributeUse.Auto
			Or CommonAttributeItem.Use = CommonAttributeUse.DontUse Then 
				Return False;
		Else
				Return True;
		EndIf;
	EndIf;
	
EndFunction

Function GenerateSelectionCondition(Val TableAlias, Val Filter)
	
	FilterRow = ""; // Part of the query text with a condition created by filter
	FilterParameters = New Structure;
	If Filter.Count() > 0 Then
		For Each FilterDescription IN Filter Do
			If Not IsBlankString(FilterRow) Then
				FilterRow = FilterRow + " AND ";
			EndIf;
			
			ParameterName = "P" + Format(FilterParameters.Count(), "NZ=0; NG=");
			FilterParameters.Insert(ParameterName, FilterDescription.Value);
			
			Operand = "&" + ParameterName;
			
			If FilterDescription.ComparisonType = ComparisonType.Equal Then
				LogicalOperator = "=";
			ElsIf FilterDescription.ComparisonType = ComparisonType.NotEqual Then
				LogicalOperator = "<>";
			ElsIf FilterDescription.ComparisonType = ComparisonType.InList Then
				LogicalOperator = "In";
				Operand = "(" + Operand + ")";
			ElsIf FilterDescription.ComparisonType = ComparisonType.NotInList Then
				LogicalOperator = "NOT IN";
				Operand = "(" + Operand + ")";
			ElsIf FilterDescription.ComparisonType = ComparisonType.Greater Then
				LogicalOperator = ">";
			ElsIf FilterDescription.ComparisonType = ComparisonType.GreaterOrEqual Then
				LogicalOperator = ">=";
			ElsIf FilterDescription.ComparisonType = ComparisonType.Less Then
				LogicalOperator = "<";
			ElsIf FilterDescription.ComparisonType = ComparisonType.LessOrEqual Then
				LogicalOperator = "<=";
			Else
				MessagePattern = NStr("en='%1 comparison kind is not supported.';ru='Вид сравнения %1 не поддерживается.'");
				MessageText = ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(MessagePattern, FilterDescription.ComparisonType);
			EndIf;
			
			FilterRow = FilterRow + TableAlias + "." + FilterDescription.Field + " " + LogicalOperator + " " + Operand;
		EndDo;
	EndIf;
	
	Return New Structure("FilterCondition, FilterParameters", FilterRow, FilterParameters);
	
EndFunction



