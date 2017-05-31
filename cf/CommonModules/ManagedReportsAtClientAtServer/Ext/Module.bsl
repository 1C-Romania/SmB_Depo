Function SetFilter(Filter,FilterFieldName,FilterFieldValue,ClearWhenEmpty = True,FilterComparisonType,DataCompositionID = Undefined) Export
	
	NewFilter = DataCompositionAtClientAtServer.FindFilterItemByDataCompositionID(Filter,DataCompositionID);
	If NewFilter = Undefined Then	
		NewFilter = Filter.Items.Add(Type("DataCompositionFilterItem"));
	EndIf;	
	NewFilter.LeftValue = New DataCompositionField(FilterFieldName);
	NewFilter.RightValue = FilterFieldValue;
	NewFilter.ComparisonType = FilterComparisonType;
	If NOT ValueIsFilled(FilterFieldValue) Then
		NewFilter.Use = NOT ClearWhenEmpty;
	Else	
		NewFilter.Use = True;
	EndIf;	
	
	Return Filter.GetIDByObject(NewFilter);
	
EndFunction	

&AtClient
Function FindFilterItemByDataCompositionID(Filter, DataCompositionID = Undefined) Export
	
	If DataCompositionID = Undefined Then 
		Return Undefined;
	Else	
		Return Filter.GetObjectByID(DataCompositionID);
	EndIf;	
		
EndFunction	