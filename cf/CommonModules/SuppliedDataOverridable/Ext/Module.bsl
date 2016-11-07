///////////////////////////////////////////////////////////////////////////////////
// SuppliedDataOverridable: the mechanism of the supplied data service.
//
///////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for the SuppliedData subsystem
// SuppliedDataOverridable general module.
//

// Register the handlers of supplied data.
//
// When getting notification of new common data accessibility the procedure is called.
// AvailableNewData modules registered through GetSuppliedDataHandlers.
// Descriptor is passed to the procedure - XDTOObject Descriptor.
// 
// IN case the AvailableNewData sets the Import argument to True,
// the data is imported, the descriptor and path to the data file are passed to the procedure.
// ProcessNewData. File will be deleted automatically after completion of the procedure.
// If the file was not specified in the service manager - The argument value is Undefined.
//
// Parameters: 
//   Handlers, ValueTable - The table for adding handlers. 
//      Columns:
//       DataKind, string - the code of data kind processed by the handler.
// 	  HandlersCode, row(20) - it will be used during restoring data processing after the failure.
// 	  Handler,  CommonModule - the module that contains the following procedures:
// 	   AvailableNewData(Handle, Import) Export
// 		 ProcessNewData(Handle, PathToFile) Export
// 		 DataProcessingCanceled(Handle) Export
//
Procedure GetSuppliedDataHandlers(Handlers) Export
	
EndProcedure

#EndRegion
