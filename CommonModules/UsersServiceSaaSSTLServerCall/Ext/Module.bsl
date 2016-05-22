#Region ServiceProceduresAndFunctions

// See this procedure in the UsersServiceSaaSSTL module.
// It supports a thick client (client server option).
//
Procedure GetUserFormProcessing(Source, FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing) Export
	
	UsersServiceSaaSSTL.GetUserFormProcessing(
		Source,
		FormKind,
		Parameters,
		SelectedForm,
		AdditionalInformation,
		StandardProcessing
	);
	
EndProcedure

#EndRegion