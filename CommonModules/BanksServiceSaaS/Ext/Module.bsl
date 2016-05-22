////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks in service model".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData"].Add(
			"BanksServiceSaaS");
	EndIf;
	
EndProcedure

// Imports the file of the RF banks classifier from the data supplied by a service manager.
//
Procedure ImportRFBanksClassifier() Export
	
	Descriptors = SuppliedData.ProvidedDataFromManagerDescriptors("RFBanks");
	
	If Descriptors.Descriptor.Count() < 1 Then
		Raise(NStr("en = 'There is no ""RFBanks"" data kind in the service manager.'"));
	EndIf;
	
	SuppliedData.ImportAndProcessData(Descriptors.Descriptor[0]);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Registers the handlers of supplied data.
//
Procedure RegisterProvidedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "RFBanks";
	Handler.ProcessorCode = "ImportingRFBanksClassifier";
	Handler.Handler = BanksServiceSaaS;
	
EndProcedure

// It is called when a notification of new data received.
// IN the body you should check whether this data is necessary for the application, and if so, select the Import check box.
// 
// Parameters:
//   Handle   - XDTOObject Descriptor.
//   Import   - Boolean, return.
//
Procedure AvailableNewData(Val Handle, Import) Export
	
	If Handle.DataType = "RFBanks" Then
		Import = True;
	EndIf;
	
EndProcedure

// It is called after the call AvailableNewData, allows you to parse data.
//
// Parameters:
//   Handle       - XDTOObject Descriptor.
//   PathToFile   - String or Undefined. The full name of the extracted file. File will be automatically deleted after procedure completed.
//                  If the file was not specified
//                  in the service manager - the argument value is Undefined.
//
Procedure ProcessNewData(Val Handle, Val PathToFile) Export
	
	If Handle.DataType = "RFBanks" AND ValueIsFilled(PathToFile) Then
		WorkWithBanks.ImportDataFromRBKFile(PathToFile);
	EndIf;
	
EndProcedure

// It is called on a data processing cancel in case of failure.
//
Procedure DataProcessingCanceled(Val Handle) Export 
	
	// you do not need to do anything.
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Register the handlers of supplied data.
//
// When getting notification of new common data accessibility the procedure is called.
// AvailableNewData modules registered through GetSuppliedDataHandlers.
// Descriptor is passed to the procedure - XDTOObject Descriptor.
// 
// IN case if AvailableNewData sets the argument to Import in value is true, the data is importing, the handle and the path to the file with data pass to a procedure.
// ProcessNewData. File will be automatically deleted after procedure completed.
// If the file was not specified in the service manager - The argument value is Undefined.
//
// Parameters: 
//   Handlers, ValueTable - The table for adding handlers. 
//       Columns:
//        DataKind, string - the code of data kind processed by the handler.
//        HandlersCode, row(20) - it will be used during restoring data processing after the failure.
//        Handler,  CommonModule - the module that contains the following procedures:
//          AvailableNewData(Handle, Import) Export
//          ProcessNewData(Handle, PathToFile) Export
//          DataProcessingCanceled(Handle) Export
//
Procedure OnDefenitionHandlersProvidedData(Handlers) Export
	
	RegisterProvidedDataHandlers(Handlers);
	
EndProcedure

#EndRegion
