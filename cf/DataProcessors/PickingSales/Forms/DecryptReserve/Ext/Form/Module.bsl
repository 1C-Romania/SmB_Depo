
////////////////////////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE
//

&AtServer
// Procedure sets values of the dynamic lists parameters 
//
// Values are written from the processor attributes
//
Procedure SetDynamicListParameters()
	
	ListReserveDecryption.Parameters.SetParameterValue("Company",		SmallBusinessServer.GetCompany(Parameters.Company));
	ListReserveDecryption.Parameters.SetParameterValue("ProductsAndServices",		Parameters.ProductsAndServices);
	ListReserveDecryption.Parameters.SetParameterValue("Characteristic",	Parameters.Characteristic);
	
EndProcedure // SetDynamicListParameters()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS
//

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetDynamicListParameters();
	
	ProductsAndServices = Parameters.ProductsAndServices;
	Characteristic = Parameters.Characteristic;
	
EndProcedure // OnCreateAtServer()
