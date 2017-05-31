Procedure FillCheckProcessing(Object, Cancel, CheckedAttributes) Export 
	
	If Object.SettingsComposer.Settings.AdditionalProperties.Property("SkipFillCheck") Then
		CheckedAttributes.Clear();
		Return;
	EndIf;	
	
	For Each SchemaParameter In Object.DataCompositionSchema.Parameters Do
		
		If SchemaParameter.DenyIncompleteValues Then
			CheckedAttributes.Add(SchemaParameter.Name);
		EndIf;	
		
	EndDo;	

EndProcedure

Procedure CommonComposeResult(ReportObject,Result, DetailsData, StandardProcessing, OutputIntoReportForm = True, ExternalDataSets = Undefined) Export
	
	StandardProcessing = False;
	
	// apply data parameters to report objcet
	For Each Attribute In ReportObject.Metadata().Attributes Do
		
		FoundDataParameter = ReportsModulesAtClientAtServer.GetSettingsParameter(ReportObject.SettingsComposer.Settings,Attribute.Name);
		If FoundDataParameter<>Undefined Then
			
			ReportObject[Attribute.Name] = FoundDataParameter.Value;
			
		EndIf;	
		
	EndDo;	
	
	ReportObject.SettingsComposer.Settings.AdditionalProperties.Insert("NotOrdinaryRunMode",True);
	
	ReportObject.GenerateReport(Result, DetailsData, OutputIntoReportForm);
	
EndProcedure

Function GetPeriodDataParameterValueAsDate(Val PeriodDataParameterValue) Export
	
	If TypeOf(PeriodDataParameterValue) = Type("StandardBeginningDate") Then
		Return PeriodDataParameterValue.Value.Value;
	Else
		Return  PeriodDataParameterValue.Value;
	EndIf;
	
EndFunction

Procedure SaveReportSettingFromReportStructure(Val ReportStructure) Export
	SettingsStorages.ReportSettings.Save(ReportStructure.ReportMetadataName,ReportStructure.SettingsKey,ReportStructure.Settings,Undefined,String(SessionParameters.CurrentUser));
	SaveLastReportUsedSetting(ReportStructure.ReportMetadataName,ReportStructure.SettingsKey);	
EndProcedure	

Procedure SaveLastReportUsedSetting(Val ReportName,Val SettingKey) Export
	SystemSettingsStorage.Save(ReportName+"/CurrentVariantKey","",SettingKey,"");	
EndProcedure

Function GetReportStructureForSaving(Val ReportSettings, Val ReportAttributes) Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ComposerSettings", ReportSettings);
	ParametersStructure.ComposerSettings.AdditionalProperties.Clear();
	
	For Each KeyAndValue In ReportAttributes Do
		
		FoundDataParameter = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter(KeyAndValue.Key));
		If FoundDataParameter<>Undefined Then
			ParametersStructure.Insert(KeyAndValue.Key,FoundDataParameter.Value);
		EndIf;	
		
	EndDo;	
	
	Return ParametersStructure;
	
EndFunction	

Function SaveReportByRef(Val ReportSettings, Val ReportAttributes,Val SettingsRef, Val SettingNewName = "") Export
	
	ReturnStructure = New Structure("IsError, ErrorDescription",False,"");
	
	SettingsObject = SettingsRef.GetObject();
	If SettingsObject.Owner <> SessionParameters.CurrentUser
		AND NOT (IsInRole(Metadata.Roles.Role_SystemSettings) 
		OR IsInRole(Metadata.Roles.Right_Administration_ConfigurationAdministration)) Then
		// can't write setting for other user
		
		ReturnStructure.IsError = True;
		ReturnStructure.ErrorDescription = Nstr("en = 'You''re not allowed to save other users settings'; pl = 'Nie możesz zapisywać ustawień innych użytkowników'");
		
	Else	
		
		If NOT IsBlankString(SettingNewName) Then
			SettingsObject.Description = SettingNewName;
		EndIf;	
		
		ReportStructure = ReportsModulesAtServer.GetReportStructureForSaving(ReportSettings,ReportAttributes);
		SettingsObject.SettingsStorage = New ValueStorage(ReportStructure);
		
		Try
			SettingsObject.Write();
		Except
			ReturnStructure.IsError = True;
			ReturnStructure.ErrorDescription = ErrorDescription();

		EndTry	
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction	

Function SetSettingSaveAutomaticallyByRef(Val SettingsRef, Val SaveAutomatically) Export
	
	ReturnStructure = New Structure("IsError, ErrorDescription",False,"");
	
	SettingsObject = SettingsRef.GetObject();
	If SettingsObject.Owner <> SessionParameters.CurrentUser
		AND NOT (IsInRole(Metadata.Roles.Role_SystemSettings) 
		OR IsInRole(Metadata.Roles.Right_Administration_ConfigurationAdministration)) Then
		// can't write setting for other user
		
		ReturnStructure.IsError = True;
		ReturnStructure.ErrorDescription = Nstr("en = 'You''re not allowed to save other users settings'; pl = 'Nie możesz zapisywać ustawień innych użytkowników'");
		
	Else	
		
		SettingsObject.SaveAutomatically = SaveAutomatically;
		
		Try
			SettingsObject.Write();
		Except
			ReturnStructure.IsError = True;
			ReturnStructure.ErrorDescription = ErrorDescription();

		EndTry	
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction	

Procedure FillReportWithSettingsByKey(ReportSettings,Val ObjectKey, Val SettingsKey) Export

	Query = New Query;
	Query.Text = "SELECT TOP 1
	             |	SavedSettings.Presentation,
	             |	SavedSettings.SettingsStorage,
	             |	SavedSettings.SaveAutomatically,
	             |	SavedSettings.Ref,
	             |	SavedSettings.SettingsKey,
	             |	SavedSettings.Owner
	             |FROM
	             |	Catalog.SavedSettings AS SavedSettings
	             |WHERE
	             |	NOT SavedSettings.DeletionMark
	             |	AND CASE
	             |			WHEN &SettingsKey = """"
	             |				THEN SavedSettings.SettingsKey LIKE ""%%Default%%""
	             |						AND SavedSettings.Owner = &CurrentUser
	             |			ELSE SavedSettings.SettingsKey = &SettingsKey
	             |		END
	             |	AND SavedSettings.SetupObject = &ObjectKey";
	Query.SetParameter("ObjectKey",StrReplace(ObjectKey,"Report.","ReportObject."));
	Query.SetParameter("SettingsKey",SettingsKey);
	Query.SetParameter("CurrentUser",SessionParameters.CurrentUser);

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		// top 1 - so only 1 iteration
		FillReportWithSettingsBySelection(ReportSettings, Selection);
	EndDo;	
	
EndProcedure	

Procedure FillReportWithSettingsByRef(ReportSettings,Val ObjectKey, Val SettingsRef) Export

	Query = New Query;
	Query.Text = "SELECT TOP 1
	             |	SavedSettings.Presentation,
	             |	SavedSettings.SettingsStorage,
	             |	SavedSettings.SaveAutomatically,
	             |	SavedSettings.Ref,
	             |	SavedSettings.SettingsKey,
	             |	SavedSettings.Owner
	             |FROM
	             |	Catalog.SavedSettings AS SavedSettings
	             |WHERE
	             |	NOT SavedSettings.DeletionMark
	             |	AND SavedSettings.SetupObject = &ObjectKey
	             |	AND SavedSettings.Ref = &SettingsRef";
	Query.SetParameter("ObjectKey",StrReplace(ObjectKey,"Report.","ReportObject."));
	Query.SetParameter("SettingsRef",SettingsRef);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		// top 1 - so only 1 iteration
		FillReportWithSettingsBySelection(ReportSettings, Selection);
	EndDo;	
	
EndProcedure	

// internal
Procedure FillReportWithSettingsBySelection(ReportSettings, Val Selection)
	
	SettingsStructure = Selection.SettingsStorage.Get();
	If SettingsStructure <> Undefined Then
		ReportSettings.LoadSettings(SettingsStructure.ComposerSettings);
		ReportSettings.Settings.AdditionalProperties.Clear();
		ReportSettings.Settings.AdditionalProperties.Insert("SaveAutomatically", Selection.SaveAutomatically);
		ReportSettings.Settings.AdditionalProperties.Insert("SettingRef",Selection.Ref);
		ReportSettings.Settings.AdditionalProperties.Insert("SettingKey",Selection.SettingsKey);
		ReportSettings.Settings.AdditionalProperties.Insert("SettingPresentation",Selection.Presentation);
		ReportSettings.Settings.AdditionalProperties.Insert("SettingOwner",Selection.Owner);
	EndIf;	
	
EndProcedure




