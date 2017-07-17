#Region ProgramInterface

// Deletes setting from the storage.
//
// Parameters:
//   ReportKey - Key of setting object. 
//       - Undefined - Settings of all reports are deleted.
//       - String       - Full report name with a dot.
//   VariantKey - Deleted setting key.
//       - Undefined - Delete all report variants.
//       - String       - Report variant key.
//   User - Settings of this user are deleted.
//       - Undefined                   - Settings of all users are deleted.
//       - String                         - IB user name.
//       - UUID        - IB user ID.
//       - InfobaseUser - IB User.
//       - CatalogRef.Users  - User.
//
// See also:
//   SettingsStandardStorageManager.Delete in the syntax-assistant.
//
Procedure Delete(ReportKey, VariantKey, User) Export
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
	QueryText = 
	"SELECT ALLOWED DISTINCT
	|	Variants.Ref
	|FROM
	|	Catalog.ReportsVariants AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.Author = &Author
	|	AND Variants.Author.InfobaseUserID = &GUID
	|	AND Variants.VariantKey = &VariantKey
	|	AND Variants.DeletionMark = FALSE
	|	AND Variants.User = TRUE";
	
	Query = New Query;
	
	If ReportKey = Undefined Then
		QueryText = StrReplace(QueryText, "Variants.Report = &Report", "TRUE");
	Else
		ReportInformation = ReportsVariants.GenerateInformationAboutReportByDescriptionFull(ReportKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		Query.SetParameter("Report", ReportInformation.Report);
	EndIf;
	
	If VariantKey = Undefined Then
		QueryText = StrReplace(QueryText, "And Variants.VariantKey = &VariantKey", "");
	Else
		Query.SetParameter("VariantKey", VariantKey);
	EndIf;
	
	If User = Undefined Then
		
		QueryText = StrReplace(QueryText, "And Variants.Author = &Author", "");
		QueryText = StrReplace(QueryText, "And Variants.Author.InfobaseUserID = &GUID", "");
	
	ElsIf TypeOf(User) = Type("CatalogRef.Users") Then
		
		Query.SetParameter("Administrator", User);
		QueryText = StrReplace(QueryText, "And Variants.Author.InfobaseUserID = &GUID", "");
		
	Else
		
		If TypeOf(User) = Type("UUID") Then
			UserID = User;
		Else
			If TypeOf(User) = Type("String") Then
				IBUser = InfobaseUsers.FindByName(User);
				If IBUser = Undefined Then
					Return;
				EndIf;
			ElsIf TypeOf(User) = Type("InfobaseUser") Then
				IBUser = User;
			Else
				Return;
			EndIf;
			UserID = IBUser.UUID;
		EndIf;
		
		Query.SetParameter("GUID", UserID);
		QueryText = StrReplace(QueryText, "And Variants.Author = &Author", "");
		
	EndIf;
	
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VariantObject = Selection.Ref.GetObject();
		VariantObject.SetDeletionMark(True);
	EndDo;
	
	
#EndIf
EndProcedure

// Receives a setting list from storage. Setting keys are list item values.
//
// Parameters:
//   ReportKey   - String - Full report name with a dot.
//   User - Settings of this user are received. optional parameter.
//       - Undefined                   - Current user settings are received.
//       - String                         - IB user name.
//       - UUID        - IB user ID.
//       - InfobaseUser - IB User.
//       - CatalogRef.Users  - User.
//
// Returns: 
//   ValueList - Report variant list.
//       * Value      - String - Variant key.
//       * Presentation - String - Variant presentation.
//
// IMPORTANT:
//   Unlike the platform mechanism instead of the right "DataAdministration" access rights to the report are checked.
//
// See also:
//   "StandardSettingStorageManager.ReceiveList" in the syntax-assistant.
//
Function GetList(ReportKey, User = Undefined) Export
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Result = New ValueList;
	
	If TypeOf(ReportKey) = Type("String") Then
		ReportInformation = ReportsVariants.GenerateInformationAboutReportByDescriptionFull(ReportKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ReportKey;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	Variants.VariantKey,
	|	Variants.Description
	|FROM
	|	Catalog.ReportsVariants AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.Author = &Administrator
	|	AND Variants.Author.InfobaseUserID = &GUID
	|	AND Variants.DeletionMark = FALSE
	|	AND Variants.User = TRUE";
	Query.SetParameter("Report", ReportRef);
	
	CurrentUser = Users.CurrentUser();
	
	If User = Undefined Then
		
		Query.SetParameter("Administrator", CurrentUser);
		Query.Text = StrReplace(Query.Text, "And Variants.Author.InfobaseUserID = &GUID", "");
	
	ElsIf TypeOf(User) = Type("CatalogRef.Users") Then
		
		Query.SetParameter("Administrator", User);
		Query.Text = StrReplace(Query.Text, "And Variants.Author.InfobaseUserID = &GUID", "");
		
	Else
		
		If TypeOf(User) = Type("UUID") Then
			UserID = User;
		Else
			If TypeOf(User) = Type("String") Then
				SetPrivilegedMode(True);
				IBUser = InfobaseUsers.FindByName(User);
				SetPrivilegedMode(False);
				If IBUser = Undefined Then
					Return Result;
				EndIf;
			ElsIf TypeOf(User) = Type("InfobaseUser") Then
				IBUser = User;
			Else
				Return Result;
			EndIf;
			UserID = IBUser.UUID;
		EndIf;
		
		Query.SetParameter("GUID", UserID);
		Query.Text = StrReplace(Query.Text, "AND Variants.Author = &Administrator", "");
		
	EndIf;
	
	VariantTable = Query.Execute().Unload();
	For Each TableRow IN VariantTable Do
		Result.Add(TableRow.VariantKey, TableRow.Description);
	EndDo;
	
	Return Result;
#EndIf
EndFunction

#EndRegion

#Region EventsHandlers

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Report variant setting reading handler.
//
// Parameters:
//   ReportKey        - String - Full report name with a dot.
//   VariantKey      - String - Report variant key.
//   Settings         - Arbitrary     - Report variant settings.
//   SettingsDescription  - SettingsDescription - Additional setting description.
//   User      - String           - IB user name.
//       It is not used so subsystem "Report variants" does not divide by authors.
//       Storage uniqueness and selection are guaranteed with uniqueness of report and variants key pairs.
//
// See also:
//   "SettingStorageManager.<StorageName>.ImportProcessor" in the syntax-assistant.
//
Procedure ImportProcessing(ReportKey, VariantKey, Settings, SettingsDescription, User)
	If Not ReportsVariantsReUse.ReadRight() Then
		Return;
	EndIf;
	
	If TypeOf(ReportKey) = Type("String") Then
		ReportInformation = ReportsVariants.GenerateInformationAboutReportByDescriptionFull(ReportKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ReportKey;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	ReportsVariants.Description,
	|	ReportsVariants.Settings
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Report = &Report
	|	AND ReportsVariants.VariantKey = &VariantKey";
	Query.SetParameter("Report",        ReportRef);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If SettingsDescription = Undefined Then
			SettingsDescription = New SettingsDescription;
			SettingsDescription.ObjectKey  = ReportKey;
			SettingsDescription.SettingsKey = VariantKey;
			SettingsDescription.User = User;
		EndIf;
		SettingsDescription.Presentation = Selection.Description;
		Settings = Selection.Settings.Get();
	EndIf;
	
EndProcedure

// Report variant setting record handler.
//
// Parameters:
//   ReportKey        - String - Full report name with a dot.
//   VariantKey      - String - Report variant key.
//   Settings         - Arbitrary         - Report variant settings.
//   SettingsDescription  - SettingsDescription     - Additional setting description.
//   User      - String, Undefined - IB user name.
//       It is not used so subsystem "Report variants" does not divide by authors.
//       Storage uniqueness and selection are guaranteed with uniqueness of report and variants key pairs.
//
// See also:
//   "SettingStorageManager.<StorageName>.SaveProcessor" in the syntax-assistant.
//
Procedure SaveProcessing(ReportKey, VariantKey, Settings, SettingsDescription, User)
	If Not ReportsVariantsReUse.AddRight() Then
		Raise NStr("en='Insufficient rights to save report variants.';ru='Недостаточно прав для сохранения вариантов отчетов'");
	EndIf;
	
	ReportInformation = ReportsVariants.GenerateInformationAboutReportByDescriptionFull(ReportKey);
	
	If TypeOf(ReportInformation.ErrorText) = Type("String") Then
		Raise ReportInformation.ErrorText;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ReportsVariants.Ref
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Report = &Report
	|	AND ReportsVariants.VariantKey = &VariantKey";
	Query.SetParameter("Report",        ReportInformation.Report);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		VariantObject = Selection.Ref.GetObject();
		If TypeOf(Settings) = Type("DataCompositionSettings") Then
			Address = CommonUseClientServer.StructureProperty(Settings.AdditionalProperties, "Address");
			If TypeOf(Address) = Type("String") AND IsTempStorageURL(Address) Then
				Settings = GetFromTempStorage(Address);
			EndIf;
		EndIf;
		VariantObject.Settings = New ValueStorage(Settings);
		If SettingsDescription <> Undefined Then
			VariantObject.Description = SettingsDescription.Presentation;
		EndIf;
		VariantObject.Write();
	EndIf;
	
EndProcedure

// Report variant setting description receive handler.
//
// Parameters:
//   ReportKey       - String - Full report name with a dot.
//   VariantKey     - String - Report variant key.
//   SettingsDescription - SettingsDescription     - Additional setting description.
//   User     - String, Undefined - IB user name.
//       It is not used so subsystem "Report variants" does not divide by authors.
//       Storage uniqueness and selection are guaranteed with uniqueness of report and variants key pairs.
//
// See also:
//   "SettingStorageManager.<StorageName>.DescriptionReceiveProcessor" in the syntax-assistant.
//
Procedure GetDescriptionProcessing(ReportKey, VariantKey, SettingsDescription, User)
	If Not ReportsVariantsReUse.ReadRight() Then
		Return;
	EndIf;
	
	If TypeOf(ReportKey) = Type("String") Then
		ReportInformation = ReportsVariants.GenerateInformationAboutReportByDescriptionFull(ReportKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ReportKey;
	EndIf;
	
	If SettingsDescription = Undefined Then
		SettingsDescription = New SettingsDescription;
	EndIf;
	
	SettingsDescription.ObjectKey  = ReportKey;
	SettingsDescription.SettingsKey = VariantKey;
	
	If TypeOf(User) = Type("String") Then
		SettingsDescription.User = User;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	Variants.Presentation AS Presentation,
	|	Variants.DeletionMark,
	|	Variants.User
	|FROM
	|	Catalog.ReportsVariants AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.VariantKey = &VariantKey";
	Query.SetParameter("Report",        ReportRef);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		SettingsDescription.Presentation = Selection.Presentation;
		SettingsDescription.AdditionalProperties.Insert("DeletionMark", Selection.DeletionMark);
		SettingsDescription.AdditionalProperties.Insert("User", Selection.User);
	EndIf;
EndProcedure

// Report variant setting description set handler.
//
// Parameters:
//   ReportKey       - String - Full report name with a dot.
//   VariantKey     - String - Report variant key.
//   SettingsDescription - SettingsDescription - Additional setting description.
//   User     - String           - IB user name.
//       It is not used so subsystem "Report variants" does not divide by authors.
//       Storage uniqueness and selection are guaranteed with uniqueness of report and variants key pairs.
//
// See also:
//   "SettingStorageManager.<StorageName>.DescriptionSetProcessor" in the syntax-assistant.
//
Procedure SetDescriptionProcessing(ReportKey, VariantKey, SettingsDescription, User)
	If Not ReportsVariantsReUse.AddRight() Then
		Raise NStr("en='Insufficient rights to save report variants.';ru='Недостаточно прав для сохранения вариантов отчетов'");
	EndIf;
	
	If TypeOf(ReportKey) = Type("String") Then
		ReportInformation = ReportsVariants.GenerateInformationAboutReportByDescriptionFull(ReportKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ReportKey;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	Variants.Ref
	|FROM
	|	Catalog.ReportsVariants AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.VariantKey = &VariantKey";
	Query.SetParameter("Report",        ReportRef);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		VariantObject = Selection.Ref.GetObject();
		VariantObject.Description = SettingsDescription.Presentation;
		VariantObject.Write();
	EndIf;
	
EndProcedure

#EndIf

#EndRegion