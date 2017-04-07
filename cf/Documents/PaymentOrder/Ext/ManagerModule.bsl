#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

// Procedure forms and displays a printable document form by the specified layout.
//
Function PrintForm(ObjectsArray, PrintObjects)
	
EndFunction // PrintForm()

// Generate printed forms of objects
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
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export

EndProcedure

#EndRegion

#EndIf