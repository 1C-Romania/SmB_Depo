////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Handlers of the subscriptions to events.

// See this procedure in the AttachedFiles module.
// It supports a thick client (client server option).
//
Procedure OverrideReceivedFormAttachedFile(Source,
                                                      FormKind,
                                                      Parameters,
                                                      SelectedForm,
                                                      AdditionalInformation,
                                                      StandardProcessing) Export
	
	AttachedFilesServiceServerCall.OverrideReceivedFormAttachedFile(
		Source,
		FormKind,
		Parameters,
		SelectedForm,
		AdditionalInformation,
		StandardProcessing);
		
EndProcedure

#EndRegion
