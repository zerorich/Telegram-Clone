import { Modal } from './Modal.jsx'
import { Button } from './Button.jsx'

export function ComingSoonModal({ open, onClose }) {
  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Скоро"
      size="sm"
      footer={
        <Button variant="primary" onClick={onClose}>
          OK
        </Button>
      }
    >
      <p style={{ margin: 0, color: 'var(--text)', fontSize: 15 }}>
        Эта функция в разработке
      </p>
    </Modal>
  )
}
