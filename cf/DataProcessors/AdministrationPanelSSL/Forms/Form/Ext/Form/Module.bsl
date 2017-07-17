#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	Cancel = True;
	ShowMessageBox(, NStr("en='Data processor is not intended for direct usage.';ru='Обработка не предназначена для непосредственного использования.'"));
EndProcedure

#EndRegion