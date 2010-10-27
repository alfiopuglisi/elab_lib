;+
;
; Residual modes m=Rs
;
; modes are in meter rms, surface.
; To convert to wavefront use self->reflcoef()
;
;-

function AOresidual_modes::Init, root_obj, slopes, rec
    self._rec    =  ptr_new(rec)
    self._slopes =  ptr_new(slopes)

    self._store_fname     = filepath(root=root_obj->elabdir(), 'residual_modes.sav')
    self._store_psd_fname = filepath(root=root_obj->elabdir(), 'residual_modes_psd.sav')
    if root_obj->recompute() eq 1B then begin
        file_delete, self._store_fname, /allow_nonexistent
        file_delete, self._store_psd_fname, /allow_nonexistent
    endif

    self._root_obj = root_obj

    if not self->AOtime_series::Init((root_obj->frames_counter())->deltat(), fftwindow="hamming", nwindows=root_obj->n_periods()) then return,0
	self._norm_factor   = 1e9 * self._root_obj->reflcoef()	;nm wf
	self._spectra_units = textoidl('[nm-wf Hz^{-1/2}]')
	self._plots_title = root_obj->tracknum()

    ; create residual_modes and analyze
    ;self->datiProducer

    ;self->AOtime_series::Compute


    ; initialize help object and add methods and leafs
    if not self->AOhelp::Init('AOresidual_modes', 'Modal wavefront residue') then return, 0
    self->addMethodHelp, "modes()", "modal residue (m rms, surface) [niter, nmodes]"
    self->addMethodHelp, "slopes()", "reference to slopes object"
    self->addMethodHelp, "rec()", "reference to modal reconstructor object"
    self->addMethodHelp, "nmodes()", "number of residual modes"
    self->AOtime_series::addHelp, self
    return, 1
end

pro AOresidual_modes::datiProducer

    if file_test(self._store_fname) then begin
        restore, self._store_fname
    endif else begin
        ; compute residual modes from slopes and modal rec
        t_rec = (*self._rec->rec())[*,*self._rec->modes_idx()]
        modes =  t_rec ##  *self._slopes->slopes()
        save, modes, file=self._store_fname
    endelse
    self._modes = ptr_new(modes, /no_copy)

end

;function AOresidual_modes::variance
;    if (PTR_VALID(self._variance)) THEN return, *(self._variance) else return, 0d
;end

function AOresidual_modes::modes, _extra=ex ;TODO add extra for series_idx or iter_idx
    ;if (PTR_VALID(self._modes)) THEN return, *(self._modes) else return, 0d
    return, self->dati(_extra=ex)
end

function AOresidual_modes::slopes
    if (OBJ_VALID(*self._slopes)) THEN return, *self._slopes else return, 0d
end

function AOresidual_modes::rec
    if (OBJ_VALID(*self._rec)) THEN return, *self._rec else return, 0d
end

function AOresidual_modes::nmodes
    return, self->AOtime_series::nseries()
end

pro AOresidual_modes::plotJitter, from_freq=from_freq, to_freq=to_freq, _extra=ex
    coeff2arcsec = self._root_obj->reflcoef() * 4 / ao_pupil_diameter() / 4.848d-6
    freq = self->freq(from=from_freq, to=to_freq)
    tip  = self->power(0, from=from_freq, to=to_freq, /cum) * coeff2arcsec^2
    tilt = self->power(1, from=from_freq, to=to_freq, /cum) * coeff2arcsec^2
    plot, freq, sqrt(tip + tilt), $
        title=self._plots_title, xtitle='Freq [Hz]', ytitle='Jitter [arcsec]', _extra=ex
    oplot, freq, sqrt(tip), col='0000ff'x
    oplot, freq, sqrt(tilt), col='00ff00'x
    legend, ['Tilt+Tip', 'Tip', 'Tilt'],/fill,psym=[6,6,6],colors=['ffffff'x, '0000ff'x, '00ff00'x]

    sigmatot2 = max ( tip + tilt)  / 2
    ldmas = 1.6d-6 / ao_pupil_diameter() / 4.848d-6 ; l/D in arcsec
    print, 'SR attenuation in H band due to TT jitter ', 1. / (1. + (!pi^2 /2 )*( sqrt(sigmatot2)/ ldmas)^2)
end


; to be implemented in AOtime_series subclasses
function AOresidual_modes::GetDati
    if not ptr_valid(self._modes) then self->datiProducer
    return, self._modes
end

pro AOresidual_modes::free
    ptr_free, self._modes
    self->AOtime_series::free
end


pro AOresidual_modes::Cleanup
    ;obj_destroy, self._obj_psd
    ptr_free, self._modes
    self->AOtime_series::Cleanup
    self->AOhelp::Cleanup
end

pro AOresidual_modes__define
    struct = { AOresidual_modes, $
        _modes         : ptr_new(), $
        _slopes        : ptr_new(), $
        _rec           : ptr_new(), $
        _store_fname   : "" ,       $
        _root_obj      : obj_new(), $
        INHERITS    AOtime_series, $
        INHERITS    AOhelp $
    }

end