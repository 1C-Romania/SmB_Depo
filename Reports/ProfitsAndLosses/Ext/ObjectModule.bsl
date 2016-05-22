#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	CompanyPresentation = "";
	
	FieldCompany = New DataCompositionField("Company");
	UserSettingID = "";
	
	For Each FilterItem IN ThisObject.SettingsComposer.Settings.Filter.Items Do
		
		If FilterItem.LeftValue = FieldCompany Then
			UserSettingID = FilterItem.UserSettingID;
			Break;
		EndIf;
		
	EndDo;
	
	UserSettingsItem = ThisObject.SettingsComposer.UserSettings.Items.Find(UserSettingID);
	If UserSettingsItem <> Undefined 
		AND UserSettingsItem.Use = True 
		AND (UserSettingsItem.ComparisonType = DataCompositionComparisonType.Equal
		OR UserSettingsItem.ComparisonType = DataCompositionComparisonType.InList) Then
		
		CompanyValue = UserSettingsItem.RightValue;
		If TypeOf(CompanyValue) = Type("CatalogRef.Companies") AND ValueIsFilled(CompanyValue) Then
			
			CompanyPresentation = CompanyValue.Description;
			
		ElsIf TypeOf(CompanyValue) = Type("ValueList") Then
			
			ItemArray = New Array;
			
			For Each ItemOfList IN CompanyValue Do
				If ValueIsFilled(ItemOfList.Value) AND ItemArray.Find(ItemOfList.Value) = Undefined Then
					CompanyPresentation = CompanyPresentation + ", " + ItemOfList.Value.Description;
					ItemArray.Add(ItemOfList.Value);
				EndIf;
			EndDo;
			
			CompanyPresentation = Right(CompanyPresentation, StrLen(CompanyPresentation)-2);
			
		EndIf;
		
	EndIf;
	
	ParemeterCompany = New DataCompositionParameter("CompanyPresentation");
	ParameterValue = ThisObject.SettingsComposer.Settings.DataParameters.FindParameterValue(ParemeterCompany);
	If ParameterValue <> Undefined Then
		
		ParameterValue.Value = CompanyPresentation;
		ParameterValue.Use = True;
		
	EndIf;
	
EndProcedure

#EndIf