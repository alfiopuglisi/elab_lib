
; xelab.pro - graphic interface for elab lib
;
; HISTORY
; Jul 2011 A. Puglisi


; ----------------

function dummy
common xelab_common, ids, cur, cur_days, cur_tracknums
end


; fill this function for regular (timer-based) updates
function update_status

end

pro disp_mess, msg
   print, msg
end

pro xelab_resize_event, ev
common xshow, par

;WIDGET_CONTROL, par.draw, $
;                XSIZE = ev.X, $
;                YSIZE = ev.Y
;
;update_display, par
;update_label, par

print, 'resize_event'
help,ev,/STR

end



pro set_status, msg, READY = READY, BUSY = BUSY
common xelab_common

    if keyword_set(READY) then msg = 'READY'
    if keyword_set(BUSY) then msg = 'BUSY ('+msg+')'

    widget_control, ids.status, SET_VALUE = msg
end

; --------------
;
; Read current dataset and display value in the listbox 
pro read_cur_dataset, RECALC = RECALC
common xelab_common

     set_status,'Reading dataset...', /BUSY
     dataset = obj_new('aodataset', from=cur.day+'_000000', to=cur.day+'_235959', REC = RECALC)
     log_twiki, dataset, TEXT = text, VALID = VALID
     print,VALID
     widget_control, ids.acqlist, SET_VALUE = text
     cur.n_acq = n_elements(text)
     widget_control, ids.numacq_label, SET_VALUE = '# of acq: '+strtrim(cur.n_acq,2)
     cur_tracknums = VALID
     set_status,/READY
end

; -----------
;
; display PSF in common display area

pro show_cur_psf
common xelab_common
    set_status,'Generating PSF...', /BUSY
    WIDGET_CONTROL, ids.display, /DESTROY
    ids.display     = WIDGET_BASE(ids.rootdisplay, XSIZE=400, YSIZE=300)
    (cur.ee)->psf, PARENT = ids.display
    set_status,/READY
end


pro show_cur_modalplot
common xelab_common
    set_status,'Generating modalplot...', /BUSY
    WIDGET_CONTROL, ids.display, /DESTROY
    ids.display     = WIDGET_DRAW(ids.rootdisplay, RETAIN=2, XSIZE=400, YSIZE=300)
    WIDGET_CONTROL, ids.display, GET_VALUE=w
    wset, w
    (cur.ee)->modalplot
    set_status, /READY
end

pro show_cur_summary
common xelab_common
    set_status,'Generating summary...', /BUSY
    (cur.ee)->summary, TEXT = TEXT
    WIDGET_CONTROL, ids.summary, SET_VALUE= TEXT
    set_status, /READY
end


; --------------
;
; General event function

pro xelab_event, event
common xelab_common

   help,event,/STR

if (event.id eq event.handler) then begin ; A top level resize event

    WIDGET_CONTROL, event.top, $
                XSIZE = event.X, $
                YSIZE = event.Y

endif else begin


    WIDGET_CONTROL, event.id, GET_UVALUE = uvalue
    print, uvalue
    CASE uvalue OF
        'exit': begin
            WIDGET_CONTROL, event.top, /DESTROY
        end

        'daylist': begin
            cur.day = cur_days[event.index]
            read_cur_dataset
        end
        'acqlist_recalc': begin
            if (cur.n_acq gt 1) then begin
                ans = dialog_message('Recalculation of '+strtrim(cur.n_acq,2)+' acquisitions will take a while. Do you want to continue?', /QUEST)
                if ans eq 'Yes' then begin
                    read_cur_dataset, /RECALC
                endif
            endif
        end
        'acqlist': begin
            if event.index gt 0 then begin
                set_status,'Reading acquisition...', /BUSY
                cur.tracknum = cur_tracknums[event.index-1]
                cur.ee = getaoelab(cur.tracknum)
                show_cur_summary
                show_cur_psf
                set_status, /READY
            endif
        end
        'disp_selection':begin
            if event.select eq 1 then begin
                case event.value of
                    'psf_display':begin
                         show_cur_psf
                    end
                    'modalplot':begin
                         show_cur_modalplot
                    end
                endcase
            endif
        end
        'acq_recalc':begin
             set_status,'Recalculating acquisition...', /BUSY
             cur.ee = getaoelab(cur.tracknum, /REC)
             show_cur_summary
             show_cur_psf
             set_status, /READY
        end

    endcase


endelse

end


; --------------------------
;
; Menu initialization

pro init_menu, base_bar

end


pro xelab, MODAL = MODAL
common xelab_common

    ao_init

    ids = {base_root    : 0L, $
           status       : 0L, $
           daylist      : 0L, $
           acqlist      : 0L, $
           numacq_label : 0L, $
           rec_button   : 0L, $
           summary      : 0L, $
           rootdisplay  : 0L, $
           display      : 0L, $
           disp_selection: 0L, $
           recalc_acq   : 0L, $
           dummy: 0 }

    cur = { day   : '', $
            n_acq : 0L, $
            tracknum: '', $
            ee    : obj_new(), $
           dummy: 0 }

    ids.base_root = widget_base(TITLE = 'Xelab', $
                         /COLUMN, MODAL=modal, /TLB_SIZE_EVENTS)
    WIDGET_CONTROL, /MANAGED, ids.base_root

    init_menu, base_bar

    ; Base for status widgets
    statusrow = widget_base(ids.base_root, /ROW, /FRAME)
    dd = widget_label(statusrow, VALUE='Status:')
    ids.status = widget_label(statusrow, VALUE='Ready', XSIZE=200)

    ; base for selection panels
    base_select = widget_base(ids.base_root, /ROW, /FRAME)

    ; Day list
    cur_days = reverse(FILE_SEARCH(GETENV('ADOPT_DATA')+'/towerdata/adsec_data/20*'))
    for i=0, n_elements(cur_days)-1 do cur_days[i] = file_basename(cur_days[i])

    ids.daylist = WIDGET_LIST(base_select, VALUE=cur_days, $
                                       UVALUE='daylist', XSIZE=10, YSIZE=15)

    ; Acquisition list (log twiki)
    base_acqlist = WIDGET_BASE(base_select, /COLUMN)
    ids.acqlist = WIDGET_LIST(base_acqlist, VALUE=strarr(1),  $
                                       UVALUE='acqlist', XSIZE=100, YSIZE=20)
    base_acqlist2 = WIDGET_BASE(base_acqlist, /ROW)
    ids.numacq_label = widget_label(base_acqlist2, VALUE='', XSIZE=150, YSIZE=20)
    ids.rec_button = WIDGET_BUTTON(base_acqlist2, VALUE='Force recalc', UVALUE='acqlist_recalc')

    ; Acq detail
    base_acq = WIDGET_BASE(base_acqlist, /ROW)

    base_acqinfo = WIDGET_BASE(ids.base_root, /ROW)

    ids.summary = WIDGET_TEXT(base_acqinfo, VALUE='', XSIZE=50, YSIZE=20)
    ids.rootdisplay = WIDGET_BASE(base_acqinfo, XSIZE=400,YSIZE=300)
    ids.display     = WIDGET_BASE(ids.rootdisplay)

    base_selection = WIDGET_BASE(base_acqinfo, /COLUMN, XSIZE=50)
    ids.disp_selection = CW_BGROUP(base_selection, ['Psf display', 'Modalplot'], $
                                         BUTTON_UVALUE=['psf_display', 'modalplot'], $
                                         UVALUE = 'disp_selection', $
                                         COLUMN=1, /EXCLUSIVE, SET_VALUE=0)

    base_buttons = WIDGET_BASE(ids.base_root, /ROW)
    ids.recalc_acq = WIDGET_BUTTON(base_buttons, VALUE='Force recalc', UVALUE='acq_recalc')
     
    

    widget_control, ids.base_root, /REALIZE

    XMANAGER,'xelab', ids.base_root, /NO_BLOCK;, $
                                    ;EVENT_HANDLER = 'xelab_resize_event' ; Routine to handle events not generated
                                                                         ;   in the draw window

end

