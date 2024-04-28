;;; 
;;; bus.lisp
;;;
;;; named-amp-buses are dsps which get registered in both the dsp registry
;;; and a bus registry. The bus registry can be used to assign outputs
;;; of sound producing dsps to the bus, finding their bus channel by
;;; id or name lookup in the bus-registry.
;;;
;;; **********************************************************************
;;; Copyright (c) 2024 Orm Finnendahl <orm.finnendahl@selma.hfmdk-frankfurt.de>
;;;
;;; Revision history: See git repository.
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the Gnu Public License, version 2 or
;;; later. See https://www.gnu.org/licenses/gpl-2.0.html for the text
;;; of this agreement.
;;; 
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;;; GNU General Public License for more details.
;;;
;;; **********************************************************************

(in-package :clog-dsp-widgets)

#|
;;; deprecated (using *dsps* for searching)

(defparameter *dsp-buses* (make-hash-table :test #'equal))

(defun add-bus (named-amp-bus)
  (with-slots (id name) named-amp-bus
    (if (or (gethash id *dsp-buses*)
            (gethash name *dsp-buses*))
        (error "bus name or id already registered: ~a ~a" name id)
        (progn
          (setf (gethash id *dsp-buses*) named-amp-bus)
          (setf (gethash name *dsp-buses*) named-amp-bus)))))

(defun find-bus (id-or-name)
  (gethash id-or-name *dsp-buses*))

(defun remove-bus (id-or-name)
  (let ((named-amp-bus (find-bus id-or-name)))
    (when named-amp-bus
        (with-slots (id bus-name) named-amp-bus
          (remhash id *dsp-buses*)
          (remhash bus-name *dsp-buses*)))))

(defun list-buses ()
  (format t "~&registered buses:")
  (maphash (lambda (key bus) bus (format t "~&~a" key)) *dsp-buses*))

(defun bus-channel (id-or-name)
  (let ((named-amp-bus (find-bus id-or-name)))
    (if named-amp-bus
        (slot-value named-amp-bus 'audio-bus)
        (progn
          (warn "audio-bus of ~S not found, using channel 0" id-or-name)
          0))))
|#

(defclass named-bus (cuda-dsp)
  ((name :initarg :name :initform "" :accessor bus-name)
   (num :initform 2 :initarg :num :accessor num-channels)
   (audio-bus :initform 0 :initarg :audio-bus :accessor audio-bus)
   (create-bus :initform t :initarg :create-bus :type boolean)
   (channel-offset :initform 0 :initarg :channel-offset :accessor channel-offs)))

(defmethod initialize-instance :after ((instance named-bus) &rest initargs)
  (declare (ignorable initargs))
  (with-slots (meter-type num nodes node-group audio-bus channel-offset create-bus unwatch cleanup) instance
    (when create-bus
      (incudine.util:msg :warn "creating named bus")
      (master-out-dsp
       :id-callback (lambda (id) (push id nodes))
       :audio-bus audio-bus
       :channel-offset channel-offset
       :num-channels num
       :group node-group))))

#|
(defmethod cuda-dsp-cleanup ((instance named-bus))
  (call-next-method))
|#


(defclass named-amp-bus (named-bus)
  ((amp-node :initform nil :accessor amp-node)
   (amp :initform (make-ref 1.0d0) :initarg :amp :accessor bus-amp)))

(defmethod initialize-instance :after ((instance named-amp-bus) &rest initargs)
  (declare (ignorable initargs))
  (with-slots (meter-type num nodes node-group audio-bus amp-node channel-offset create-bus unwatch cleanup) instance
    (when create-bus
      (incudine.util:msg :warn "creating amp control")
      (bus-amp-dsp :id-callback (lambda (id) (setf amp-node id))
                   :num-channels num :group node-group)
      (loop until (and nodes amp-node))
      (dolist (n nodes) (move n :after amp-node)))))

(defmethod cuda-dsp-cleanup ((instance named-amp-bus))
  (with-slots (amp-node) instance
    (free amp-node))
  (call-next-method))
