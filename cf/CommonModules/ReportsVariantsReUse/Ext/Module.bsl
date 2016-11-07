////////////////////////////////////////////////////////////////////////////////
// Subsystem "Variants of reports" (server, perf. perf.).
// 
// It is executed on server, the return values are cached for the time of the session.
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Generates the list of the configuration reports that are available for the current user.
//
// Returns:
//   Array of <see. Catalogs.ReportsVariants.Attributes.Report> -
//       Reports references are available for the current user.
//
// Description:
//   This array should be used in all queries
//   to the ReportVariants catalog table as the filter by the Report attribute.
//
Function AvailableReports() Export
	Result = New Array;
	
	For Each ReportMetadata IN Metadata.Reports Do
		If AccessRight("view", ReportMetadata)
			AND CommonUse.MetadataObjectAvailableByFunctionalOptions(ReportMetadata) Then
			Result.Add(CommonUse.MetadataObjectID(ReportMetadata));
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Generates the list of configuration report variants that are not available for the current user by functional options.
//
// Returns:
//   Array of CatalogRef.PredefinedReportsVariants -
//       Report variants that are disabled by the functional options.
//
// Description:
//   This array should be used in all queries
//   to the ReportVariants catalog table as an excluding filter by the PredefinedVariant attribute.
//
Function DisabledApplicationOptions() Export
	// Get options that are unavailable by functional options.
	
	ConstantValue = Constants.ReportVariantParameters.Get();
	Structure = ConstantValue.Get();
	OptionsTable = Structure.TableFunctionalOptions;
	OptionsTable.Columns.Add("ReportIsAvailable", New TypeDescription("Boolean"));
	OptionsTable.Columns.Add("OptionValue", New TypeDescription("Number"));
	
	UserReporting = ReportsVariantsReUse.AvailableReports();
	For Each ReportRef IN UserReporting Do
		Found = OptionsTable.FindRows(New Structure("Report", ReportRef));
		For Each TableRow IN Found Do
			TableRow.ReportIsAvailable = True;
			Value = GetFunctionalOption(TableRow.FunctionalOptionName);
			If Value = True Then
				TableRow.OptionValue = 1;
			EndIf;
		EndDo;
	EndDo;
	
	OptionsTable.GroupBy("PredefinedVariant, ReportIsAvailable", "OptionValue");
	VariantTable = OptionsTable.Copy(New Structure("ReportIsAvailable, OptionValue", True, 0));
	VariantTable.GroupBy("PredefinedVariant");
	DisabledVariants = VariantTable.UnloadColumn("PredefinedVariant");
	
	// Add variants that were disabled by the developer.
	Query = New Query;
	Query.SetParameter("UserReporting", UserReporting);
	Query.SetParameter("ArrayOfDisabled", DisabledVariants);
	Query.Text =
	"SELECT ALLOWED
	|	PredefinedReportsVariants.Ref
	|FROM
	|	Catalog.PredefinedReportsVariants AS PredefinedReportsVariants
	|WHERE
	|	PredefinedReportsVariants.Enabled = FALSE
	|	AND PredefinedReportsVariants.Report IN(&UserReporting)
	|	AND Not PredefinedReportsVariants.Ref IN (&ArrayOfDisabled)
	|	AND PredefinedReportsVariants.DeletionMark = FALSE";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DisabledVariants.Add(Selection.Ref);
	EndDo;
	
	Return DisabledVariants;
EndFunction

// Generates the tree of subsystems that are available for the current user.
//
// Returns: 
//   Result - ValueTree -
//       * SectionRef      - CatalogRef.MetadataObjectIDs - Ref of section.
//       * Ref             - CatalogRef.MetadataObjectIDs - Ref of subsystem.
//       * Name            - String - Subsystem name.
//       * DescriptionFull - String - Full name of the subsystem.
//       * Presentation    - String - Presentation of the subsystem.
//       * Priority        - String - Subsystem priority.
//
Function CurrentUserSubsystems() Export
	Result = New ValueTree;
	Result.Columns.Add("Ref",              New TypeDescription("CatalogRef.MetadataObjectIDs"));
	Result.Columns.Add("Name",                 ReportsVariants.TypeDescriptionString(150));
	Result.Columns.Add("FullName",           ReportsVariants.TypeDescriptionString(510));
	Result.Columns.Add("Presentation",       ReportsVariants.TypeDescriptionString(150));
	Result.Columns.Add("SectionRef",        New TypeDescription("CatalogRef.MetadataObjectIDs"));
	Result.Columns.Add("Priority",           ReportsVariants.TypeDescriptionString(100));
	Result.Columns.Add("FullPresentation", ReportsVariants.TypeDescriptionString(300));
	
	RootRow = Result.Rows.Add();
	RootRow.Ref = Catalogs.MetadataObjectIDs.EmptyRef();
	RootRow.Presentation = NStr("en='All sections';ru='Все разделы'");
	
	ReportsVariants.AddCurrentUserSubsystems(RootRow, Undefined, Undefined);
	
	Return Result;
EndFunction

// Returns True if a user has a right to read the variants of reports.
Function ReadRight() Export
	Return AccessRight("Read", Metadata.Catalogs.ReportsVariants);
EndFunction

// Returns True if a user has a right to save the variants of reports.
Function AddRight() Export
	Return AccessRight("SaveUserData", Metadata) AND AccessRight("Insert", Metadata.Catalogs.ReportsVariants);
EndFunction

// The array of reports that store the settings of the ReportForm common form and redefine them in a module of the object.
//
// Returns:
//   Array of <see. Catalogs.ReportsVariants.Attributes.Report> -
//       The references of reports in the objects modules of which there is the DefineFormSettings procedure().
//
// See also:
//   ReportsVariantsOverridable.SetReportsVariants().
//
Function ReportsWithSettings() Export
	ConstantValue = Constants.ReportVariantParameters.Get();
	ReportsWithSettings = ConstantValue.Get().ReportsWithSettings;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.WhenDefineReportsWithSettings(ReportsWithSettings);
	EndIf;
	
	Return ReportsWithSettings;
EndFunction

#EndRegion
