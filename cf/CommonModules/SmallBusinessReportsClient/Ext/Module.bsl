
// Opens a predefined report option
//
// Parameters:
//  Variant  - Structure - description of a report option:
//     * ReportName           - String - report
//     name * VariantKey        - String - key of a report option
//
Procedure OpenReportOption(Variant) Export
	
	OpenParameters = New Structure;
	OpenParameters.Insert("VariantKey", Variant.VariantKey);
	
	Uniqueness = "Report." + Variant.ReportName + "/VariantKey." + Variant.VariantKey;
	
	OpenParameters.Insert("PrintParametersKey",        Uniqueness);
	OpenParameters.Insert("WindowOptionsKey", Uniqueness);
	
	OpenForm("Report." + Variant.ReportName + ".Form", OpenParameters, Undefined, Uniqueness);
	
EndProcedure

Procedure DetailProcessing(ThisForm, Item, Details, StandardProcessing) Export
	
	If ThisForm.UniqueKey = "Report.AccountsReceivableDynamics/VariantKey.DebtDynamics" Then
		
		StandardProcessing = False;
		
		ReportOptionProperties = New Structure("VariantKey, ObjectKey",
			"Default", "Report.AccountsReceivableAgingRegistry");
		
		ReportVariantSettingsLinker = SmallBusinessReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
		If ReportVariantSettingsLinker = Undefined Then
			Return;
		EndIf;
		
		CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
		CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
		
		ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
		
		PeriodValue = SmallBusinessReportsServerCall.ReceiveDecryptionValue("Period", Details, ThisForm.ReportDetailsData);
		If PeriodValue <> Undefined Then
			LayoutParameter = New DataCompositionParameter("PeriodUs");
			For Each SettingItem IN ReportVariantUserSettings.Items Do
				If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") AND SettingItem.Parameter = LayoutParameter Then
					ParameterValue = SettingItem;
					If TypeOf(ParameterValue.Value) = Type("StandardBeginningDate") Then
						ParameterValue.Value.Variant = StandardBeginningDateVariant.Custom;
						ParameterValue.Value.Date = PeriodValue;
						ParameterValue.Use = True;
					EndIf;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		ReportParameters = New Structure("UserSettings, 
											|VariantKey, 
											|PurposeUseKey, 
											|GenerateOnOpen",
											ReportVariantUserSettings,
											ReportOptionProperties.VariantKey,
											"CustomersDebtDynamicsDecryption",
											True);
		
		OpenForm("Report.AccountsReceivableAgingRegister.Form", ReportParameters);
		
	ElsIf ThisForm.UniqueKey = "Report.DynamicsOfDebtToSuppliers/VariantKey.DebtDynamics" Then
		
		StandardProcessing = False;
		
		ReportOptionProperties = New Structure("VariantKey, ObjectKey",
			"Default", "Report.AccountsPayableAgingRegistry");
		
		ReportVariantSettingsLinker = SmallBusinessReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
		If ReportVariantSettingsLinker = Undefined Then
			Return;
		EndIf;
		
		CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
		CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
		
		ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
		
		PeriodValue = SmallBusinessReportsServerCall.ReceiveDecryptionValue("DynamicPeriod", Details, ThisForm.ReportDetailsData);
		If PeriodValue <> Undefined Then
			LayoutParameter = New DataCompositionParameter("PeriodUs");
			For Each SettingItem IN ReportVariantUserSettings.Items Do
				If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") AND SettingItem.Parameter = LayoutParameter Then
					ParameterValue = SettingItem;
					If TypeOf(ParameterValue.Value) = Type("StandardBeginningDate") Then
						ParameterValue.Value.Variant = StandardBeginningDateVariant.Custom;
						ParameterValue.Value.Date = PeriodValue;
						ParameterValue.Use = True;
					EndIf;
					
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		ReportParameters = New Structure("UserSettings, 
											|VariantKey, 
											|PurposeUseKey, 
											|GenerateOnOpen",
											ReportVariantUserSettings,
											ReportOptionProperties.VariantKey,
											"DebtToVendorsDynamicsDecryption",
											True);
		
		OpenForm("Report.AccountsPayableAgingRegister.Form", ReportParameters);
		
	EndIf;
	
EndProcedure

Procedure CopyFilter(LinkerReceiver, LinkerSource) Export
	
	ReceiverSettings = LinkerReceiver.Settings;
	SourceSettings = LinkerSource.Settings;
	UserSettingsSource = LinkerSource.UserSettings;
	
	For Each FilterItem IN SourceSettings.Filter.Items Do
		If ValueIsFilled(FilterItem.UserSettingID) Then
			
			For Each UserSetting IN UserSettingsSource.Items Do
				If UserSetting.UserSettingID = FilterItem.UserSettingID Then
					If TypeOf(UserSetting) = Type("DataCompositionFilterItem")
						AND UserSetting.Use Then
						
						CommonUseClientServer.SetFilterItem(
							ReceiverSettings.Filter,
							String(FilterItem.LeftValue),
							UserSetting.RightValue,
							UserSetting.ComparisonType,
							,
							True);
						
					EndIf;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	LinkerReceiver.LoadSettings(ReceiverSettings);

EndProcedure











