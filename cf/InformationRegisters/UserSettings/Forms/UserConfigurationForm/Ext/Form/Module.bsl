//By transferred data create string tree on form
//
// Selection - query sample with data in hierarchy
// ValueTree - value tree items for which strings are created
//
Function AddRowsIntoTree(Selection, ValueTree)
	
	While Selection.Next() Do
		
		NewRowOfSetting = ValueTree.Add();
		FillPropertyValues(NewRowOfSetting, Selection);
		NewRowOfSetting.Value = Selection.Setting.ValueType.AdjustValue(Selection.Value);
		
		RowsOfSelection = Selection.Select(QueryResultIteration.ByGroupsWithHierarchy);
		If RowsOfSelection.Count() > 0 Then
			
			AddRowsIntoTree(RowsOfSelection, NewRowOfSetting.GetItems());
			
		EndIf;
		
	EndDo;
	
EndFunction

// Procedure updates information in the setting table.
//
Procedure FillTree()

	SettingsItems = SettingsTree.GetItems();
	SettingsItems.Clear();

	Query = New Query;
	Query.SetParameter("User", User);
	Query.Text=
	"SELECT
	|	Settings.Parent,
	|	Settings.Ref AS Setting,
	|	Settings.IsFolder AS IsFolder,
	|	Not Settings.IsFolder AS PictureNumber,
	|	SettingsValue.Value,
	|	Constants.FunctionalOptionAccountingByMultipleCompanies,
	|	Constants.FunctionalOptionAccountingByMultipleWarehouses,
	|	Constants.FunctionalOptionAccountingByMultipleDivisions
	|FROM
	|	ChartOfCharacteristicTypes.UserSettings AS Settings
	|		LEFT JOIN InformationRegister.UserSettings AS SettingsValue
	|		ON (SettingsValue.Setting = Settings.Ref)
	|			AND (SettingsValue.User = &User),
	|	Constants AS Constants
	|WHERE
	|	Not Settings.DeletionMark
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.MainCompany)
	|				AND Not Constants.FunctionalOptionAccountingByMultipleCompanies)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.MainWarehouse)
	|				AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.MainDivision)
	|				AND Not Constants.FunctionalOptionAccountingByMultipleDivisions)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.StatusOfNewCustomerOrder)
	|				AND Not Constants.UseCustomerOrderStates)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.StatusOfNewPurchaseOrder)
	|				AND Not Constants.UsePurchaseOrderStates)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.StatusOfNewProductionOrder)
	|				AND Not Constants.UseProductionOrderStates)
	|	AND (Settings.Parent <> VALUE(ChartOfCharacteristicTypes.UserSettings.MultiplePickSetting)
	|		OR Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.UseNewSelectionMechanism))
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.UsePerformerSalariesInJobOrder)
	|				AND Not Constants.FunctionalOptionUseSubsystemPayroll)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.UsePerformerSalariesInJobOrder)
	|				AND Not Constants.FunctionalOptionUseWorkSubsystem)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.UseMaterialsInJobOrder)
	|				AND Not Constants.FunctionalOptionUseWorkSubsystem)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.UseConsumerMaterialsInJobOrder)
	|				AND Not Constants.FunctionalOptionUseWorkSubsystem)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.UseProductsInJobOrder)
	|				AND Not Constants.FunctionalOptionUseWorkSubsystem)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.WorkKindPositionInJobOrder)
	|				AND Not Constants.FunctionalOptionUseWorkSubsystem)
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.DataImportMethodFromExternalSources))
	|	AND Not(Settings.Ref = VALUE(ChartOfCharacteristicTypes.UserSettings.DataImportFromExternalSources))
	|
	|ORDER BY
	|	IsFolder HIERARCHY,
	|	Settings.Description";
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	AddRowsIntoTree(Selection, SettingsItems);
	
EndProcedure // FillTree()

// Procedure writes the setting values into the information register.
//
Procedure UpdateSettings()
	
	RecordSet = InformationRegisters.UserSettings.CreateRecordSet();
	
	RecordSet.Filter.User.Use = True;
	RecordSet.Filter.User.Value      = User;
	
	SettingsGroups = SettingsTree.GetItems();
	For Each SettingsGroup IN SettingsGroups Do
		
		SettingsItems = SettingsGroup.GetItems();
		
		For Each SettingsRow IN SettingsItems Do
			
			Record = RecordSet.Add();
			
			Record.User = User;
			Record.Setting    = SettingsRow.Setting;
			Record.Value     = SettingsRow.Setting.ValueType.AdjustValue(SettingsRow.Value);
			
		EndDo;
		
	EndDo;
	
	RecordSet.Write();
	
	RefreshReusableValues();
	
EndProcedure // UpdateSettings()

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("User") Then
		
		User = Parameters.User;
		
		If ValueIsFilled(User) Then
			
			MainDivision = ChartsOfCharacteristicTypes.UserSettings.MainDivision;
			MainWarehouse = ChartsOfCharacteristicTypes.UserSettings.MainWarehouse;
			
			ChoiceParametersDivision = Enums.StructuralUnitsTypes.Division;
			
			ChoiceParametersWarehouse = New ValueList;
			ChoiceParametersWarehouse.Add(Enums.StructuralUnitsTypes.Warehouse);
			ChoiceParametersWarehouse.Add(Enums.StructuralUnitsTypes.Retail);
			ChoiceParametersWarehouse.Add(Enums.StructuralUnitsTypes.RetailAccrualAccounting);
			
			
			FillTree();
			
		EndIf;
		
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure OnClose()
	
	UpdateSettings();
	
EndProcedure // OnClose() 

&AtClient
Procedure SettingsTreeBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData = Undefined OR Item.CurrentData.IsFolder Then
		
		Cancel = True;
		Return;
		
	ElsIf Item.CurrentData.Setting = MainDivision Then
		
		NewArray = New Array();
		NewArray.Add(New ChoiceParameter("Filter.StructuralUnitType", ChoiceParametersDivision));
		Items.SettingsTreeValue.ChoiceParameters = New FixedArray(NewArray);;
		
	ElsIf Item.CurrentData.Setting = MainWarehouse Then
		
		NewArray = New Array();
		For Each ItemOfList IN ChoiceParametersWarehouse Do
			NewArray.Add(ItemOfList.Value);
		EndDo;		
		ArrayWarehouse = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		Items.SettingsTreeValue.ChoiceParameters = New FixedArray(NewArray);
		
	EndIf;
	
EndProcedure

















