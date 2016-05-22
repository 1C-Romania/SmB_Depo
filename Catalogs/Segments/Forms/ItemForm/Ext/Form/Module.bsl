
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		
		FillInAvailableRules();
		
		If ValueIsFilled(Parameters.CopyingValue) Then
			
			For Each Rule IN Parameters.CopyingValue.UsedRules Do
				AvailableRule = FindTreeRow(AvailableRules.GetItems(), Rule.Name, Rule.DynamicRuleKey);
				If AvailableRule <> Undefined Then
					RuleSettings = Rule.Settings.Get();
					NewRule = UsedRules.Add();
					FillPropertyValues(NewRule, AvailableRule);
					NewRule.ComparisonType = RuleSettings.ComparisonType;
					NewRule.Value = RuleSettings.Value;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillInAvailableRules();
	
	UsedRules.Clear();
	
	For Each Rule IN CurrentObject.UsedRules Do
		AvailableRule = FindTreeRow(AvailableRules.GetItems(), Rule.Name, Rule.DynamicRuleKey);
		If AvailableRule <> Undefined Then
			RuleSettings = Rule.Settings.Get();
			NewRule = UsedRules.Add();
			FillPropertyValues(NewRule, AvailableRule);
			NewRule.ComparisonType = RuleSettings.ComparisonType;
			NewRule.Value = RuleSettings.Value;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.UsedRules.Clear();
	
	For Each Rule IN UsedRules Do
		NewRule = CurrentObject.UsedRules.Add();
		NewRule.Name = Rule.Name;
		NewRule.DynamicRuleKey = Rule.DynamicRuleKey;
		NewRule.Settings = New ValueStorage(
			New Structure("ComparisonType, Value", Rule.ComparisonType, Rule.Value));
	EndDo;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("AfterSegmentWriting", Object.Ref);
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure AvailableRulesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	AvailableRule = AvailableRules.FindByID(SelectedRow);
	If AvailableRule.IsFolder Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	FoundRules = UsedRules.FindRows(New Structure("Name, DynamicRuleKey", AvailableRule.Name, AvailableRule.DynamicRuleKey));
	If AvailableRule.MultipleUse Or FoundRules.Count() = 0 Then
		NewRule = UsedRules.Add();
		FillPropertyValues(NewRule, AvailableRule);
		Items.UsedRules.CurrentRow = NewRule.GetID();
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "UsedRulesPresentation" Then
		Rule = UsedRules.FindByID(SelectedRow);
		UsedRules.Delete(Rule);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesOnActivateRow(Item)
	
	If Items.UsedRules.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	UsedRule = UsedRules.FindByID(Items.UsedRules.CurrentRow);
	AvailableRule = FindTreeRow(AvailableRules.GetItems(), UsedRule.Name, UsedRule.DynamicRuleKey);
	If AvailableRule = Undefined Then
		Return;
	EndIf;
	
	SmallBusinessClientServer.FillListByList(AvailableRule.AvailableComparisonTypes, Items.UsedRulesComparisonType.ChoiceList);
	Items.UsedRulesComparisonType.ReadOnly = AvailableRule.AvailableComparisonTypes.Count() <= 1;
	
	FillPropertyValues(Items.UsedRulesValue, AvailableRule.ValueProperties);
	If ComparisonTypeList(UsedRule.ComparisonType) Then
		Items.UsedRulesValue.TypeRestriction = New TypeDescription("ValueList");
		If TypeOf(UsedRule.Value) <> Type("ValueList") Then
			UsedRule.Value = New ValueList;
			UsedRule.Value.ValueType = AvailableRule.ValueProperties.TypeRestriction;
		EndIf;
	Else
		UsedRule.Value = AvailableRule.ValueProperties.TypeRestriction.AdjustValue(UsedRule.Value);
	EndIf;
	Items.UsedRulesValue.ReadOnly = UsedRule.ComparisonType = DataCompositionComparisonType.Filled Or UsedRule.ComparisonType = DataCompositionComparisonType.NotFilled;
	
EndProcedure

&AtClient
Procedure UsedRulesDragAndDropCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	If DragParameters.Value.Count() > 0 AND TypeOf(DragParameters.Value[0]) = Type("FormDataTreeItem") Then
		StandardProcessing = False;
		For Each AvailableRule IN DragParameters.Value Do
			If AvailableRule.IsFolder Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
		EndDo;
		DragParameters.Action = DragAction.Choice;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesDragAndDrop(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	If DragParameters.Value.Count() = 0 Or TypeOf(DragParameters.Value[0]) <> Type("FormDataTreeItem") Then
		Return;
	EndIf;
	
	Filter = New Structure("Name, DynamicRuleKey");
	For Each AvailableRule IN DragParameters.Value Do
		If AvailableRule.IsFolder Then
			Continue;
		EndIf;
		Filter.Name = AvailableRule.Name;
		Filter.DynamicRuleKey = AvailableRule.DynamicRuleKey;
		FoundRules = UsedRules.FindRows(Filter);
		If AvailableRule.MultipleUse Or FoundRules.Count() = 0 Then
			NewRule = UsedRules.Add();
			FillPropertyValues(NewRule, AvailableRule);
		EndIf;
	EndDo;
	
	If NewRule <> Undefined Then
		Items.UsedRules.CurrentRow = NewRule.GetID();
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsedRulesComparisonTypeOnChange(Item)
	
	If Items.UsedRules.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	UsedRule = UsedRules.FindByID(Items.UsedRules.CurrentRow);
	AvailableRule = FindTreeRow(AvailableRules.GetItems(), UsedRule.Name, UsedRule.DynamicRuleKey);
	If AvailableRule = Undefined Then
		Return;
	EndIf;

	Value = UsedRule.Value;
	
	If ComparisonTypeList(UsedRule.ComparisonType) Then
		TypeDescriptionList = New TypeDescription("ValueList");
		UsedRule.Value = TypeDescriptionList.AdjustValue(Value);
		UsedRule.Value.ValueType = AvailableRule.ValueProperties.TypeRestriction;
		Items.UsedRulesValue.TypeRestriction = New TypeDescription("ValueList");
		Items.UsedRulesValue.ReadOnly = False;
	ElsIf UsedRule.ComparisonType = DataCompositionComparisonType.Filled Or UsedRule.ComparisonType = DataCompositionComparisonType.NotFilled Then
		UsedRule.Value = AvailableRule.FilterValueType.AdjustValue();
		Items.UsedRulesValue.ReadOnly = True;
	Else
		UsedRule.Value = AvailableRule.ValueProperties.TypeRestriction.AdjustValue(Value);
		Items.UsedRulesValue.TypeRestriction = AvailableRule.ValueProperties.TypeRestriction;
		Items.UsedRulesValue.ReadOnly = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

&AtServer
Procedure FillInAvailableRules()
	
	TreeItems = AvailableRules.GetItems();
	TreeItems.Clear();
	
	Rules = Catalogs.Segments.GetAvailableFilterRules();
	CommonUse.FillItemCollectionOfFormDataTree(TreeItems, Rules);
	
	FillInPictureIndex(TreeItems);
	
	ChoiceParameterLinks = New Array;
	ChoiceParameterLinks.Add(New ChoiceParameterLink("Filter.Owner", "Items.UsedRules.CurrentData.DynamicRuleKey"));
	Items.UsedRulesValue.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinks);
	
EndProcedure

&AtServerNoContext
Procedure FillInPictureIndex(TreeItems)
	
	For Each TreeItem IN TreeItems Do
		TreeItem.PictureIndex = ?(TreeItem.IsFolder, 2, 5);
		ChildItems = TreeItem.GetItems();
		If ChildItems.Count() > 0 Then
			FillInPictureIndex(ChildItems);
		EndIf;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function ComparisonTypeList(ComparisonTypeRules)
	
	If ComparisonTypeRules = DataCompositionComparisonType.InList
		Or ComparisonTypeRules = DataCompositionComparisonType.NotInList
		Or ComparisonTypeRules = DataCompositionComparisonType.InListByHierarchy
		Or ComparisonTypeRules = DataCompositionComparisonType.NotInListByHierarchy Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function FindTreeRow(TreeItemCollection, Name, DynamicRuleKey)
	
	For Each TreeItem IN TreeItemCollection Do
		If TreeItem.Name = Name AND TreeItem.DynamicRuleKey = DynamicRuleKey Then
			Return TreeItem;
		EndIf;
		RowItems = TreeItem.GetItems();
		If RowItems.Count() > 0 Then
			FoundString = FindTreeRow(RowItems, Name, DynamicRuleKey);
			If FoundString <> Undefined Then
				Return FoundString;
			EndIf;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion
