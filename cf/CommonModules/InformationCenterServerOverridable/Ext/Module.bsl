////////////////////////////////////////////////////////////////////////////////
// Subsystem "Information center".
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

// It defines the reference for information searching.
// For example, ITS site.
//
// Parameters:
// InformationSearchReference - String - address.
//
// Note:
// 	The structure shall be as follows:
// 	If you add the searching field to the reference address and
// 	follow this address, then we will go to the form of searching results.
//
Procedure DefineInformationSearchReference(InformationSearchReference) Export
	
EndProcedure
