
#Region ProgramInterface

// Creates new parameter structure for data import from file to the tabular section.
//
// Returns:
//   Structure - Parameters for opening the form of data import to the tabular section:
//    * TabularSectionFullName - String   - full path to the tabular
// section of the document in the form "DocumentName.TabularSectionName".
//    * Title               - String   - title of form for data import from file.
//    *LayoutNameWithTemplate      - String   - name of the layout with template for data input.
//    Author presentation           - String   - title of the window in data upoad form.
//    * AdditionalParameters - AnyType - Any additional information which will
//                                           be sent to data matching procedure.
//
Function DataImportingParameters() Export
	ExportParameters = New Structure();
	ExportParameters.Insert("TabularSectionFullName");
	ExportParameters.Insert("Title");
	ExportParameters.Insert("TemplateNameWithTemplate");
	ExportParameters.Insert("AdditionalParameters");
	
	Return ExportParameters;
EndFunction

// Opens form of data import for filling in the tabular section.
//
// Parameters: 
//   ExportParameters   - Structure           - see DataLoadFromFileClient.DataImportParameters.
//   AlertAboutImport - NotifyDescription  - alert which will be called to add imported
//                                               data to the tabular section.
//
Procedure ShowImportForm(ExportParameters, AlertAboutImport) Export
	
	OpenForm("DataProcessor.DataLoadFromFile.Form", ExportParameters, 
		AlertAboutImport.Module, , , , AlertAboutImport);
		
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Opens data import form to fill in the tabular section of references matching in subsystem "Reports options".
//
// Parameters: 
//   ExportParameters   - Structure           - see DataLoadFromFileClient.DataImportParameters.
//   AlertAboutImport - NotifyDescription  - alert which will be called to add imported
//                                               data to the tabular section.
//
Procedure ShowRefsFillingForm(ExportParameters, AlertAboutImport) Export
	
	OpenForm("DataProcessor.DataLoadFromFile.Form", ExportParameters,
		AlertAboutImport.Module,,,, AlertAboutImport);
		
EndProcedure

#EndRegion