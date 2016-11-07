#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Function returns a tabular document for printing waybill
//
Function PrintForm(ObjectsArray, PrintObjects, PrintParameters)
	
	SpreadsheetDocument			= New SpreadsheetDocument;
	Template 						= GetTemplate("PF_MXL_WayBill");
	
	If TypeOf(ObjectsArray) = Type("Array") 
		AND ObjectsArray.Count() > 0 Then
		
		CurrentDocument 		= ObjectsArray[0];
		
	Else
		
		CurrentDocument 		= Undefined;
		
	EndIf;
	
	FirstLineNumber 						= SpreadsheetDocument.TableHeight + 1;
	SpreadsheetDocument.PrintParametersName 	= "PRINT_PARAMETERS_PrintWayBill_WB";
	
	//:::Facial
	TemplateArea 				= Template.GetArea("FirstPart");
	TemplateArea.Parameters.Fill(PrintParameters);
	SpreadsheetDocument.Put(TemplateArea);
	
	SpreadsheetDocument.PutHorizontalPageBreak();
	
	//:::Reverse
	TemplateArea 				= Template.GetArea("SecondPart");
	TemplateArea.Parameters.Fill(PrintParameters);
	SpreadsheetDocument.Put(TemplateArea);
	
	PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction // PrintForm()

// Generate print form
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated by commas 
//   ObjectsArray     - Array     - Array of refs to objects that need to be printed
//   PrintParameters  - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated table documents
//   OutputParameters     - Structure    - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CN", "Application No. 4 to the Cargo transportation rules by motor transport", PrintForm(ObjectsArray, PrintObjects, PrintParameters));
	
EndProcedure

#EndIf