////////////////////////////////////////////////////////////////////////////////
// Subsystem "Change prohibition dates".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns properties that characterize the option of embedding.
Function SectionsProperties() Export
	
	Properties = New Structure;
	Properties.Insert("UseExternalUsers", False);
	
	ChangeProhibitionDatesOverridable.InterfaceSetting(Properties);
	
	Properties.Insert("ExchangePlansNodesEmptyRefs", New Array);
	Properties.Insert("UseProhibitionDatesOfDataImport", False);
	
	SettingRecipientTypes = Metadata.InformationRegisters.ChangeProhibitionDates
		.Dimensions.User.Type.Types();
	
	For Each SettingRecipientType IN SettingRecipientTypes Do
		MetadataObject = Metadata.FindByType(SettingRecipientType);
		If Metadata.ExchangePlans.Contains(MetadataObject) Then
			Properties.UseProhibitionDatesOfDataImport = True;
			Properties.ExchangePlansNodesEmptyRefs.Add(
				CommonUse.ObjectManagerByFullName(
					MetadataObject.FullName()).EmptyRef());
		EndIf;
	EndDo;
	
	Properties.Insert("AllSectionsWithoutObjects", True);
	Properties.Insert("WithoutSectionsAndObjects");
	Properties.Insert("SingleSection");
	Properties.Insert("ShowSections");
	Properties.Insert("SectionsWithoutObjects",   New ValueList);
	Properties.Insert("SectionObjectsTypes", New ValueTable);
	
	Properties.SectionObjectsTypes.Columns.Add(
		"Section", New TypeDescription("ChartOfCharacteristicTypesRef.ChangingProhibitionDatesSections"));
	
	Properties.SectionObjectsTypes.Columns.Add(
		"ObjectTypes", New TypeDescription("ValueList"));
	
	Query = New Query(
	"SELECT
	|	ChangingProhibitionDatesSections.Ref
	|FROM
	|	ChartOfCharacteristicTypes.ChangingProhibitionDatesSections AS ChangingProhibitionDatesSections
	|WHERE
	|	ChangingProhibitionDatesSections.Predefined");
	
	SetPrivilegedMode(True);
	Sections = Query.Execute().Unload().UnloadColumn("Ref");
	
	For Each Section IN Sections Do
		
		SectionDescription = Properties.SectionObjectsTypes.Add();
		SectionDescription.Section = Section;
		SectionDescription.ObjectTypes = New ValueList;
		
		For Each Type IN Section.ValueType.Types() Do
			If Type <> Type("ChartOfCharacteristicTypesRef.ChangingProhibitionDatesSections") Then
				If CommonUse.IsReference(Type) Then
					TypeMetadata = Metadata.FindByType(Type);
					SectionDescription.ObjectTypes.Add(
							TypeMetadata.FullName(),
							TypeMetadata.ObjectPresentation);
				EndIf;
			EndIf;
		EndDo;
		
		If SectionDescription.ObjectTypes.Count() <> 0 Then
			Properties.AllSectionsWithoutObjects = False;
		Else
			Properties.SectionsWithoutObjects.Add(Section);
		EndIf;
	EndDo;
	
	Properties.WithoutSectionsAndObjects = Sections.Count() = 0;
	Properties.SingleSection   = Sections.Count() = 1;
	Properties.ShowSections    = Not (  Not Properties.AllSectionsWithoutObjects
	                                    AND    Properties.SingleSection);
	
	Return New FixedStructure(Properties);
	
EndFunction

// See comment in the calling function ChangeProhibitionDates.DataTemplateForChecking().
Function DataTemplateForChecking() Export
	
	DataForChecking = New ValueTable;
	
	DataForChecking.Columns.Add(
		"Date", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	
	DataForChecking.Columns.Add(
		"Section", New TypeDescription("ChartOfCharacteristicTypesRef.ChangingProhibitionDatesSections"));
	
	DataForChecking.Columns.Add(
		"Object", Metadata.ChartsOfCharacteristicTypes.ChangingProhibitionDatesSections.Type);
	
	Return DataForChecking;
	
EndFunction

// Returns data sources, filled in procedure.
// ChangeProhibitionDatesOverridable.FillDataSourcesForChangeProhibitionCheck().
//
Function DataSourcesForChangeProhibitionCheck() Export
	
	DataSources = New ValueTable;
	DataSources.Columns.Add("Table",     New TypeDescription("String"));
	DataSources.Columns.Add("DataField",    New TypeDescription("String"));
	DataSources.Columns.Add("Section",      New TypeDescription("String"));
	DataSources.Columns.Add("ObjectField", New TypeDescription("String"));
	
	ChangeProhibitionDatesOverridable.FillDataSourcesForChangeProhibitionCheck(
		DataSources);
	
	Return DataSources;
	
EndFunction

#EndRegion
