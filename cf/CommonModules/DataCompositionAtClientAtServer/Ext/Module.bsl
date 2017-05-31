Function GetParameter(Settings, Parameter) Export
	
	ParameterValue = Undefined;
	ParametersField = ?(TypeOf(Parameter) = Type("String"), New DataCompositionParameter(Parameter), Parameter);
	
	If TypeOf(Settings) = Type("DataCompositionSettings") Then
		ParameterValue = Settings.DataParameters.FindParameterValue(ParametersField);
	ElsIf TypeOf(Settings) = Type("DataCompositionUserSettings") Then
		For Each SettingItem In Settings.Items Do
			If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") And SettingItem.Parameter = ParametersField Then
				ParameterValue = SettingItem;
				Break;
			EndIf;
		EndDo;
	ElsIf TypeOf(Settings) = Type("DataCompositionSettingsComposer") Then
		For Each SettingItem In Settings.UserSettings.Items Do
			If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") And SettingItem.Parameter = ParametersField Then
				ParameterValue = SettingItem;
				Break;
			EndIf;
		EndDo;
		If ParameterValue = Undefined Then
			ParameterValue = Settings.Settings.DataParameters.FindParameterValue(ParametersField);
		EndIf;
	ElsIf TypeOf(Settings) = Type("DataCompositionDetailsData") Then
		ParameterValue = Settings.Settings.DataParameters.FindParameterValue(ParametersField);
	ElsIf TypeOf(Settings) = Type("DataCompositionParameterValueCollection") Then
		ParameterValue = Settings.Find(ParametersField);
	ElsIf TypeOf(Settings) = Type("DataCompositionAppearance") Then
		ParameterValue = Settings.FindParameterValue(ParametersField);
	EndIf;
	
	Return ParameterValue;
	
EndFunction

Function SetParameter(Settings, Parameter, Value, Use = True) Export
	
	ParameterValue = GetParameter(Settings, Parameter);
	
	If ParameterValue <> Undefined Then
		ParameterValue.Use	= Use;
		ParameterValue.Value		= Value;
	EndIf;
	
	Return ParameterValue;
	
EndFunction

Procedure CopyItems(ReceiverValue, SourceValue, ClearReceiver = True) Export
	
	If TypeOf(SourceValue) = Type("DataCompositionConditionalAppearance")
		Or TypeOf(SourceValue) = Type("DataCompositionUserFieldsCaseVariants")
		Or TypeOf(SourceValue) = Type("DataCompositionAppearanceFields")
		Or TypeOf(SourceValue) = Type("DataCompositionDataParameterValues") Then
		CreateByType = False;
	Else
		CreateByType = True;
	EndIf;
	
	ReceiverItems = ReceiverValue.Items;
	SourceItems = SourceValue.Items;
	If ClearReceiver Then
		ReceiverItems.Clear();
	EndIf;
	
	For Each SourceItem In SourceItems Do
		
		If TypeOf(SourceItem) = Type("DataCompositionOrderItem") Then
			// Items order add in start
			IndexOf = SourceItems.IndexOf(SourceItem);
			ReceiverItem = ReceiverItems.Insert(IndexOf, TypeOf(SourceItem));
		Else
			If CreateByType Then
				ReceiverItem = ReceiverItems.Add(TypeOf(SourceItem));
			Else
				ReceiverItem = ReceiverItems.Add();
			EndIf;
		EndIf;
		
		FillPropertyValues(ReceiverItem, SourceItem);
		// In some collections you must fill other collection
		If TypeOf(SourceItems) = Type("DataCompositionConditionalAppearanceItemCollection") Then
			CopyItems(ReceiverItem.Fields, SourceItem.Fields);
			CopyItems(ReceiverItem.Filter, SourceItem.Filter);
			FillItems(ReceiverItem.Layout, SourceItem.Layout); 
		ElsIf TypeOf(SourceItems)	= Type("DataCompositionUserFieldCaseVariantCollection") Then
			CopyItems(ReceiverItem.Filter, SourceItem.Filter);
		EndIf;
		
		// In some elements collection you must fill other collection
		If TypeOf(SourceItem) = Type("DataCompositionFilterItemGroup") Then
			CopyItems(ReceiverItem, SourceItem);
		ElsIf TypeOf(SourceItem) = Type("DataCompositionSelectedFieldGroup") Then
			CopyItems(ReceiverItem, SourceItem);
		ElsIf TypeOf(SourceItem) = Type("DataCompositionUserFieldCase") Then
			CopyItems(ReceiverItem.Variants, SourceItem.Variants);
		ElsIf TypeOf(SourceItem) = Type("DataCompositionUserFieldExpression") Then
			ReceiverItem.SetDetailRecordExpression (SourceItem.GetDetailRecordExpression());
			ReceiverItem.SetTotalRecordExpression(SourceItem.GetTotalRecordExpression());
			ReceiverItem.SetDetailRecordExpressionPresentation(SourceItem.GetDetailRecordExpressionPresentation());
			ReceiverItem.SetTotalRecordExpressionPresentation(SourceItem.GetTotalRecordExpressionPresentation());
		EndIf;
		
	EndDo;
	
EndProcedure

// Filled one items collection based on another collection
Procedure FillItems(ReceiverValue, SourceValue, FirstLevel = Undefined, FillUnused = True) Export
	
	If TypeOf(ReceiverValue) = Type("DataCompositionParameterValueCollection") Then
		ValuesCollection = SourceValue;
	Else
		ValuesCollection = SourceValue.Items;
	EndIf;
	
	For each ItemSource In ValuesCollection Do
		If FirstLevel = Undefined Then
			ItemReceiver = ReceiverValue.FindParameterValue(ItemSource.Parameter);
		Else
			ItemReceiver = FirstLevel.FindParameterValue(ItemSource.Parameter);
		EndIf;
		If ItemReceiver = Undefined Then
			Continue;
		EndIf;
		If Not FillUnused AND Not ItemSource.Use Then
		Else
			FillPropertyValues(ItemReceiver, ItemSource);
		EndIf;
		If TypeOf(ItemSource) = Type("DataCompositionParameterValue") Then
			FillItems(ItemReceiver.NestedParameterValues, ItemSource.NestedParameterValues, ReceiverValue);
		EndIf;
	EndDo;
	
EndProcedure

//////////////////////////////////////////////////////////////////////

// Add filter in filter set for composer or filter group
Function AddFilter(StructureItem, Val Field, Value, ComparisonType = Undefined) Export
	
	If TypeOf(Field) = Type("String") Then
		Field = New DataCompositionField(Field);
	EndIf;
	
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") Then
		Filter = StructureItem.Settings.Filter;
	Else
		Filter = StructureItem;
	EndIf;
	
	If ComparisonType = Undefined Then
		ComparisonType = DataCompositionComparisonType.Equal;
	EndIf;
	
	NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
	NewItem.LeftValue = Field;
	NewItem.RightValue = Value;
	NewItem.ComparisonType = ComparisonType;
	Return NewItem;
	
EndFunction

Function SetFilter(Filter,FilterFieldName,FilterFieldValue,ClearWhenEmpty = True,FilterComparisonType,DataCompositionID = Undefined) Export
	
	NewFilter = FindFilterItemByDataCompositionID(Filter,DataCompositionID);
	If NewFilter = Undefined Then	
		NewFilter = Filter.Items.Add(Type("DataCompositionFilterItem"));
	EndIf;	
	NewFilter.LeftValue = New DataCompositionField(FilterFieldName);
	NewFilter.RightValue = FilterFieldValue;
	NewFilter.ComparisonType = FilterComparisonType;
	If TypeOf(FilterFieldValue) <> Type("Number") AND ValueIsNotFilled(FilterFieldValue) Then
		NewFilter.Use = NOT ClearWhenEmpty;
	Else	
		NewFilter.Use = True;
	EndIf;	
	NewFilter.UserSettingID = "TMP"+String(New UUID);

	Return Filter.GetIDByObject(NewFilter);
	
EndFunction	

Function SetUserSettingFilter(UserSettingItems,FilterFieldName,FilterFieldValue,ClearWhenEmpty = True,FilterComparisonType,DataCompositionID = Undefined) Export
	
	For Each UserSettingItem In UserSettingItems.Items Do
		If TypeOf(UserSettingItem) = Type("DataCompositionFilter") Then
			Return SetFilter(UserSettingItem,FilterFieldName,FilterFieldValue,ClearWhenEmpty,FilterComparisonType,DataCompositionID);
		EndIf;	
	EndDo;	
	
	Return Undefined;
	
EndFunction

Procedure ClearTempUserSettingFilter(UserSettingItems) Export
	For Each UserSettingItem In UserSettingItems.Items Do
		If TypeOf(UserSettingItem) = Type("DataCompositionFilter") Then
			i = 0;
			While i<UserSettingItem.Items.Count() Do
				FilterItem = UserSettingItem.Items[i];
				If NOT IsBlankString(FilterItem.UserSettingID) AND Left(FilterItem.UserSettingID,3) = "TMP" Then
					UserSettingItem.Items.Delete(FilterItem);
				Else
					i = i + 1;
				EndIf;
			EndDo;	
		EndIf;	
	EndDo;	
EndProcedure	

Function FindFilterItemByDataCompositionID(Filter, DataCompositionID = Undefined) Export
	
	If DataCompositionID = Undefined Then 
		Return Undefined;
	Else	
		Return Filter.GetObjectByID(DataCompositionID);
	EndIf;	
		
EndFunction	
